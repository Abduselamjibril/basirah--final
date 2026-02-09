<?php

namespace App\Http\Controllers;

use App\Models\Story;
use App\Models\StoryEpisode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Http\Resources\StoryEpisodeResource; // Import new resource

class StoryEpisodeController extends Controller
{
        /**
         * @OA\Get(
         *     path="/stories/{story_id}/episodes",
         *     summary="Get all episodes for a story",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="story_id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="List of story episodes.")
         * )
         */
    public function index(Story $story)
    {
        // Using the resource to transform the collection
        return StoryEpisodeResource::collection($story->storyEpisodes);
    }

        /**
         * @OA\Post(
         *     path="/stories/{story_id}/episodes",
         *     summary="Create a new episode for a story",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="story_id",
         *         in="path",
         *         required=true,
         *         description="Story ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name"},
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="video", type="string", format="binary"),
         *             @OA\Property(property="audio", type="string", format="binary"),
         *             @OA\Property(property="youtube_link", type="string")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Story episode created successfully."),
         *     @OA\Response(response=422, description="Validation error.")
         * )
         */
    public function store(Request $request, Story $story)
    {
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm', 'max: 1048576', Rule::requiredIf(fn() => !$request->filled('youtube_link'))],
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => ['nullable', 'url', Rule::requiredIf(fn() => !$request->hasFile('video'))],
        ]);

        $videoPath = $request->hasFile('video') ? $request->file('video')->store('story_episodes/videos', 'public') : null;
        $audioPath = $request->hasFile('audio') ? $request->file('audio')->store('story_episodes/audios', 'public') : null;

        $episode = $story->storyEpisodes()->create([
            'name' => $validatedData['name'],
            'video' => $videoPath,
            'audio' => $audioPath,
            'youtube_link' => $videoPath ? null : ($validatedData['youtube_link'] ?? null),
            // FIXED: New episodes inherit their locked status from the parent story.
            'is_locked' => $story->is_premium,
        ]);

        return response()->json([
            'message' => 'Story episode created successfully.',
            'data' => new StoryEpisodeResource($episode)
        ], 201);
    }

        /**
         * @OA\Get(
         *     path="/story-episodes/{id}",
         *     summary="Get a single story episode by ID",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story Episode ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story episode found."),
         *     @OA\Response(response=404, description="Story episode not found.")
         * )
         */
    public function showEpisode(StoryEpisode $storyEpisode)
    {
        return new StoryEpisodeResource($storyEpisode);
    }

        /**
         * @OA\Get(
         *     path="/story-episodes",
         *     summary="Get all story episodes across all stories",
         *     tags={"StoryEpisode"},
         *     @OA\Response(response=200, description="List of all story episodes.")
         * )
         */
    public function getAllEpisodes()
    {
        $episodes = StoryEpisode::with('story')->get(); // Eager load story for context
        return StoryEpisodeResource::collection($episodes);
    }

        /**
         * @OA\Put(
         *     path="/story-episodes/{id}",
         *     summary="Update a story episode",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story Episode ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=false,
         *         @OA\JsonContent(
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="video", type="string", format="binary"),
         *             @OA\Property(property="audio", type="string", format="binary"),
         *             @OA\Property(property="youtube_link", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Story episode updated successfully."),
         *     @OA\Response(response=404, description="Story episode not found.")
         * )
         */
    public function update(Request $request, StoryEpisode $storyEpisode)
    {
        $validatedData = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'video' => 'nullable|file|mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm|max: 1048576',
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => 'nullable|url',
        ]);

        $updateData = $request->only('name', 'youtube_link');

        if ($request->hasFile('video')) {
            if($storyEpisode->video) Storage::disk('public')->delete($storyEpisode->video);
            $updateData['video'] = $request->file('video')->store('story_episodes/videos', 'public');
            $updateData['youtube_link'] = null;
        }

        if ($request->hasFile('audio')) {
            if($storyEpisode->audio) Storage::disk('public')->delete($storyEpisode->audio);
            $updateData['audio'] = $request->file('audio')->store('story_episodes/audios', 'public');
        }

        $storyEpisode->update($updateData);

        return response()->json([
            'message' => 'Story episode updated successfully.',
            'data' => new StoryEpisodeResource($storyEpisode->refresh())
        ], 200);
    }

        /**
         * @OA\Delete(
         *     path="/story-episodes/{id}",
         *     summary="Delete a story episode",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story Episode ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story Episode deleted successfully."),
         *     @OA\Response(response=404, description="Story episode not found.")
         * )
         */
    public function destroy(StoryEpisode $storyEpisode)
    {
        if ($storyEpisode->video) Storage::disk('public')->delete($storyEpisode->video);
        if ($storyEpisode->audio) Storage::disk('public')->delete($storyEpisode->audio);
        $storyEpisode->delete();

        return response()->json(['message' => 'Story Episode deleted successfully'], 200);
    }

        /**
         * @OA\Patch(
         *     path="/story-episodes/{id}/lock",
         *     summary="Lock a story episode",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story Episode ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story Episode locked successfully."),
         *     @OA\Response(response=404, description="Story episode not found.")
         * )
         */
    public function lock(StoryEpisode $storyEpisode)
    {
        $storyEpisode->is_locked = true;
        $storyEpisode->save();

        return response()->json([
            'message' => 'Story Episode locked successfully.',
            'data' => new StoryEpisodeResource($storyEpisode)
        ]);
    }

        /**
         * @OA\Patch(
         *     path="/story-episodes/{id}/unlock",
         *     summary="Unlock a story episode",
         *     tags={"StoryEpisode"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Story Episode ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Story Episode unlocked successfully."),
         *     @OA\Response(response=404, description="Story episode not found.")
         * )
         */
    public function unlock(StoryEpisode $storyEpisode)
    {
        $storyEpisode->is_locked = false;
        $storyEpisode->save();

        return response()->json([
            'message' => 'Story Episode unlocked successfully.',
            'data' => new StoryEpisodeResource($storyEpisode)
        ]);
    }
}
