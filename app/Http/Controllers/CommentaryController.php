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
        /**
         * @OA\Get(
         *     path="/commentaries",
         *     summary="Get all commentaries",
         *     tags={"Commentary"},
         *     @OA\Response(response=200, description="List of commentaries")
         * )
         */

    public function show($id)
    {
        $commentary = Commentary::with('episodes')->find($id);
        if (!$commentary) {
            return response()->json(['error' => 'Commentary not found.'], 404);
        }
        return new CommentaryResource($commentary);
    }
        /**
         * @OA\Get(
         *     path="/commentaries/{id}",
         *     summary="Get a single commentary by ID",
         *     tags={"Commentary"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Commentary ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Commentary found"),
         *     @OA\Response(response=404, description="Commentary not found.")
         * )
         */

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
        /**
         * @OA\Post(
         *     path="/commentaries",
         *     summary="Create a new commentary",
         *     tags={"Commentary"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"title"},
         *             @OA\Property(property="title", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Commentary created successfully."),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */

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
        /**
         * @OA\Put(
         *     path="/commentaries/{id}",
         *     summary="Update a commentary",
         *     tags={"Commentary"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Commentary ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=false,
         *         @OA\JsonContent(
         *             @OA\Property(property="title", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Commentary updated successfully."),
         *     @OA\Response(response=404, description="Commentary not found.")
         * )
         */

    public function destroy($id)
    {
        $commentary = Commentary::findOrFail($id);
        if ($commentary->image) {
            Storage::disk('public')->delete($commentary->image);
        }
        $commentary->delete();
        return response()->json(['message' => 'Commentary deleted successfully.'], 200);
    }
        /**
         * @OA\Delete(
         *     path="/commentaries/{id}",
         *     summary="Delete a commentary",
         *     tags={"Commentary"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Commentary ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Commentary deleted successfully."),
         *     @OA\Response(response=404, description="Commentary not found.")
         * )
         */

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
        /**
         * @OA\Patch(
         *     path="/commentaries/{id}/lock",
         *     summary="Lock a commentary and set to premium",
         *     tags={"Commentary"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Commentary ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Commentary locked and set to premium."),
         *     @OA\Response(response=404, description="Commentary not found.")
         * )
         */

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
        /**
         * @OA\Patch(
         *     path="/commentaries/{id}/unlock",
         *     summary="Unlock a commentary and set to free",
         *     tags={"Commentary"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Commentary ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Commentary unlocked and set to free."),
         *     @OA\Response(response=404, description="Commentary not found.")
         * )
         */
}
