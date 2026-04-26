<?php

namespace App\Http\Controllers;

use App\Models\Surah;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Cache;
use App\Http\Resources\SurahResource; // Import new resource

class SurahController extends Controller
{
    public function index(Request $request)
    {
        $juz = $request->query('juz');
        $cacheKey = 'surahs_all' . ($juz ? "_juz_$juz" : "");

        $surahs = Cache::remember($cacheKey, 3600, function () use ($juz) {
            $query = Surah::withCount('episodes');
            if ($juz) {
                $query->where('juz', $juz);
            }
            return $query->latest()->get();
        });

        return SurahResource::collection($surahs);
    }

    public function show($id)
    {
        $surah = Surah::with('episodes')->find($id);
        if (!$surah) {
            return response()->json(['error' => 'Surah not found.'], 404);
        }
        // Use the resource to transform the single model
        return new SurahResource($surah);
    }

    public function store(Request $request)
    {
        // Validation logic needs to be adapted for file uploads in API context
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'boolean',
            'juz' => 'nullable|integer|min:1|max:30',
        ]);

        $surah = new Surah();
        $surah->name = $validated['name'];
        $surah->description = $validated['description'] ?? null;
        $surah->is_premium = $validated['is_premium'] ?? false;
        $surah->juz = $validated['juz'] ?? null;

        if ($request->hasFile('image')) {
            $surah->image = $request->file('image')->store('surahs', 'public');
        }

        $surah->save();

        Cache::forget('surahs_all');

        return response()->json([
            'message' => 'Surah created successfully.',
            'data' => new SurahResource($surah)
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $surah = Surah::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
            'juz' => 'sometimes|nullable|integer|min:1|max:30',
        ]);

        $surah->fill($validated);

        if ($request->hasFile('image')) {
            if ($surah->image) {
                Storage::disk('public')->delete($surah->image);
            }
            $surah->image = $request->file('image')->store('surahs', 'public');
        }

        $surah->save();

        Cache::forget('surahs_all');

        return response()->json([
            'message' => 'Surah updated successfully.',
            'data' => new SurahResource($surah)
        ], 200);
    }

    public function destroy($id)
    {
        $surah = Surah::findOrFail($id);
        // Episodes will be deleted by cascade constraint
        if ($surah->image) {
            Storage::disk('public')->delete($surah->image);
        }
        $surah->delete();
        
        Cache::forget('surahs_all');
        
        return response()->json(['message' => 'Surah deleted successfully.'], 200);
    }

    public function lock($id)
    {
        $surah = Surah::findOrFail($id);
        $surah->is_premium = true;
        $surah->save();
        $surah->episodes()->update(['is_locked' => true]);

        Cache::forget('surahs_all');

        return response()->json([
            'message' => 'Surah locked and set to premium.',
            'data' => new SurahResource($surah->load('episodes'))
        ]);
    }

    public function unlock($id)
    {
        $surah = Surah::findOrFail($id);
        $surah->is_premium = false;
        $surah->save();
        $surah->episodes()->update(['is_locked' => false]);

        Cache::forget('surahs_all');

        return response()->json([
            'message' => 'Surah unlocked and set to free.',
            'data' => new SurahResource($surah->load('episodes'))
        ]);
    }
}
