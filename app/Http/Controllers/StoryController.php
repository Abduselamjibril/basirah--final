<?php

namespace App\Http\Controllers;

use App\Models\Story;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\StoryResource; // Import new resource

class StoryController extends Controller
{
        /**
         * @OA\Get(
         *     path="/stories",
         *     summary="Get all stories with episodes and episode count",
         *     tags={"Story"},
         *     @OA\Response(response=200, description="List of stories.")
         * )
         */
    public function index()
    {
        // FIXED: Eager load relationships AND count to prevent N+1 queries.
        // `withCount` adds a `story_episodes_count` attribute to each story.
        $stories = Story::with('storyEpisodes')->withCount('storyEpisodes')->get();
        return StoryResource::collection($stories);
    }

        /**
         * @OA\Post(
         *     path="/stories",
         *     summary="Create a new story",
         *     tags={"Story"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name","description"},
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Story created successfully."),
         *     @OA\Response(response=422, description="Validation error.")
         * )
         */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'image' => 'image|nullable|max:1999',
            'is_premium' => 'sometimes|boolean',
        ]);

        $story = new Story($validated);

        if ($request->hasFile('image')) {
            $story->image = $request->file('image')->store('images', 'public');
        }

        $story->save();

        return response()->json([
            'message' => 'Story created successfully.',
            'data' => new StoryResource($story)
        ], 201);
    }

        /**
         * @OA\Get(
         *     path="/stories/{id}",
         *     summary="Get a single story by ID",
         *     tags={"Story"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story found."),
         *     @OA\Response(response=404, description="Story not found.")
         * )
         */
    public function show(Story $story)
    {
        // Eager load the relationship
        $story->load('storyEpisodes');
        return new StoryResource($story);
    }

        /**
         * @OA\Put(
         *     path="/stories/{id}",
         *     summary="Update a story",
         *     tags={"Story"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=false,
         *         @OA\JsonContent(
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Story updated successfully."),
         *     @OA\Response(response=404, description="Story not found.")
         * )
         */
    public function update(Request $request, Story $story)
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'sometimes|required|string',
            'image' => 'image|nullable|max:1999',
            'is_premium' => 'sometimes|boolean',
        ]);

        $story->fill($validated);

        if ($request->hasFile('image')) {
            if ($story->image) {
                Storage::disk('public')->delete($story->image);
            }
            $story->image = $request->file('image')->store('images', 'public');
        }

        $story->save();

        return response()->json([
            'message' => 'Story updated successfully.',
            'data' => new StoryResource($story)
        ], 200);
    }

        /**
         * @OA\Delete(
         *     path="/stories/{id}",
         *     summary="Delete a story",
         *     tags={"Story"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story deleted successfully."),
         *     @OA\Response(response=404, description="Story not found.")
         * )
         */
    public function destroy(Story $story)
    {
        if ($story->image) {
            Storage::disk('public')->delete($story->image);
        }
        $story->delete();
        return response()->json(['message' => 'Story deleted successfully'], 200);
    }

    // FIXED: Using Route-Model binding for cleaner code
        /**
         * @OA\Patch(
         *     path="/stories/{id}/lock",
         *     summary="Lock a story and set it to premium",
         *     tags={"Story"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story locked and set to premium."),
         *     @OA\Response(response=404, description="Story not found.")
         * )
         */
    public function lock(Story $story)
    {
        $story->is_premium = true;
        $story->save();
        $story->storyEpisodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Story locked and set to premium.',
            'data' => new StoryResource($story->load('storyEpisodes'))
        ]);
    }

    // FIXED: Using Route-Model binding for cleaner code
        /**
         * @OA\Patch(
         *     path="/stories/{id}/unlock",
         *     summary="Unlock a story and set it to free",
         *     tags={"Story"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story unlocked and set to free."),
         *     @OA\Response(response=404, description="Story not found.")
         * )
         */
    public function unlock(Story $story)
    {
        $story->is_premium = false;
        $story->save();
        $story->storyEpisodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Story unlocked and set to free.',
            'data' => new StoryResource($story->load('storyEpisodes'))
        ]);
    }
}
