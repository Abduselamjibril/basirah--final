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
    public function index(Story $story)
    {
        // Using the resource to transform the collection
        return StoryEpisodeResource::collection($story->storyEpisodes);
    }

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

    public function showEpisode(StoryEpisode $storyEpisode)
    {
        return new StoryEpisodeResource($storyEpisode);
    }

    public function getAllEpisodes()
    {
        $episodes = StoryEpisode::with('story')->get(); // Eager load story for context
        return StoryEpisodeResource::collection($episodes);
    }

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

    public function destroy(StoryEpisode $storyEpisode)
    {
        if ($storyEpisode->video) Storage::disk('public')->delete($storyEpisode->video);
        if ($storyEpisode->audio) Storage::disk('public')->delete($storyEpisode->audio);
        $storyEpisode->delete();

        return response()->json(['message' => 'Story Episode deleted successfully'], 200);
    }

    public function lock(StoryEpisode $storyEpisode)
    {
        $storyEpisode->is_locked = true;
        $storyEpisode->save();

        return response()->json([
            'message' => 'Story Episode locked successfully.',
            'data' => new StoryEpisodeResource($storyEpisode)
        ]);
    }

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
