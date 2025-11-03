<?php

namespace App\Http\Controllers;

use App\Models\DeeperLook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\DeeperLookResource; // Import new resource

class DeeperLookController extends Controller
{
    public function index()
    {
        $deeperLooks = DeeperLook::with('episodes')->get();
        return DeeperLookResource::collection($deeperLooks);
    }

    public function show($id)
    {
        $deeperLook = DeeperLook::with('episodes')->find($id);
        if (!$deeperLook) {
            return response()->json(['error' => 'Deeper Look not found.'], 404);
        }
        return new DeeperLookResource($deeperLook);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $deeperLook = new DeeperLook($validated);

        if ($request->hasFile('image')) {
            $deeperLook->image = $request->file('image')->store('deeperlooks', 'public');
        }

        $deeperLook->save();

        return response()->json([
            'message' => 'Deeper Look created successfully.',
            'data' => new DeeperLookResource($deeperLook)
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $deeperLook = DeeperLook::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $deeperLook->fill($validated);

        if ($request->hasFile('image')) {
            if ($deeperLook->image) {
                Storage::disk('public')->delete($deeperLook->image);
            }
            $deeperLook->image = $request->file('image')->store('deeperlooks', 'public');
        }

        $deeperLook->save();

        return response()->json([
            'message' => 'Deeper Look updated successfully.',
            'data' => new DeeperLookResource($deeperLook)
        ], 200);
    }

    public function destroy($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        if ($deeperLook->image) {
            Storage::disk('public')->delete($deeperLook->image);
        }
        $deeperLook->delete();
        return response()->json(['message' => 'Deeper Look deleted successfully.'], 200);
    }

    public function lock($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        $deeperLook->is_premium = true;
        $deeperLook->save();
        $deeperLook->episodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Deeper Look locked and set to premium.',
            'data' => new DeeperLookResource($deeperLook->load('episodes'))
        ]);
    }

    public function unlock($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        $deeperLook->is_premium = false;
        $deeperLook->save();
        $deeperLook->episodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Deeper Look unlocked and set to free.',
            'data' => new DeeperLookResource($deeperLook->load('episodes'))
        ]);
    }
}
