<?php

namespace App\Http\Controllers;

use App\Models\Commentary;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\CommentaryResource; // Import new resource

class CommentaryController extends Controller
{
    public function index()
    {
        $commentaries = Commentary::with('episodes')->get();
        return CommentaryResource::collection($commentaries);
    }

    public function show($id)
    {
        $commentary = Commentary::with('episodes')->find($id);
        if (!$commentary) {
            return response()->json(['error' => 'Commentary not found.'], 404);
        }
        return new CommentaryResource($commentary);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $commentary = new Commentary($validated);

        if ($request->hasFile('image')) {
            $commentary->image = $request->file('image')->store('commentaries', 'public');
        }

        $commentary->save();

        return response()->json([
            'message' => 'Commentary created successfully.',
            'data' => new CommentaryResource($commentary)
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $commentary = Commentary::findOrFail($id);

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        // Use fill() to handle partial updates gracefully
        $commentary->fill($validated);

        if ($request->hasFile('image')) {
            if ($commentary->image) {
                Storage::disk('public')->delete($commentary->image);
            }
            $commentary->image = $request->file('image')->store('commentaries', 'public');
        }

        $commentary->save();

        return response()->json([
            'message' => 'Commentary updated successfully.',
            'data' => new CommentaryResource($commentary)
        ], 200);
    }

    public function destroy($id)
    {
        $commentary = Commentary::findOrFail($id);
        if ($commentary->image) {
            Storage::disk('public')->delete($commentary->image);
        }
        $commentary->delete();
        return response()->json(['message' => 'Commentary deleted successfully.'], 200);
    }

    public function lock($id)
    {
        $commentary = Commentary::findOrFail($id);
        $commentary->is_premium = true;
        $commentary->save();
        $commentary->episodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Commentary locked and set to premium.',
            'data' => new CommentaryResource($commentary->load('episodes'))
        ]);
    }

    public function unlock($id)
    {
        $commentary = Commentary::findOrFail($id);
        $commentary->is_premium = false;
        $commentary->save();
        $commentary->episodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Commentary unlocked and set to free.',
            'data' => new CommentaryResource($commentary->load('episodes'))
        ]);
    }
}
