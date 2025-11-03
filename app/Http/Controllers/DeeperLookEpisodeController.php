<?php

namespace App\Http\Controllers;

use App\Models\DeeperLookEpisode;
use App\Models\DeeperLook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Http\Resources\DeeperLookEpisodeResource;

class DeeperLookEpisodeController extends Controller
{
    /**
     * Display a listing of episodes for a specific Deeper Look.
     */
    public function index(DeeperLook $deeperLook)
    {
        // REFINEMENT: Using latest() is a more expressive alias for orderBy('created_at', 'desc').
        return DeeperLookEpisodeResource::collection($deeperLook->episodes()->with('deeperLook')->latest()->get());
    }

    /**
     * Store a newly created episode.
     */
    public function store(Request $request, DeeperLook $deeperLook)
    {
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm', 'max: 1048576', Rule::requiredIf(fn() => !$request->filled('youtube_link'))],
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => ['nullable', 'url', Rule::requiredIf(fn() => !$request->hasFile('video'))],
        ]);

        $videoPath = $request->hasFile('video') ? $request->file('video')->store('deeperlooks/episodes/videos', 'public') : null;
        $audioPath = $request->hasFile('audio') ? $request->file('audio')->store('deeperlooks/episodes/audios', 'public') : null;

        $episode = $deeperLook->episodes()->create([
            'name' => $validatedData['name'],
            'video' => $videoPath,
            'audio' => $audioPath,
            'youtube_link' => $videoPath ? null : ($validatedData['youtube_link'] ?? null),
            'is_locked' => $deeperLook->is_premium,
        ]);

        return response()->json([
            'message' => 'Deeper Look episode created successfully.',
            'data' => new DeeperLookEpisodeResource($episode)
        ], 201);
    }

    /**
     * Display a specific episode.
     */
    public function show(DeeperLook $deeperLook, DeeperLookEpisode $episode)
    {
        // REFINEMENT: The manual ownership check is removed.
        // `scopeBindings()` in your route file handles this security check automatically.
        // If the episode doesn't belong to the deeperLook, Laravel returns a 404.
        return new DeeperLookEpisodeResource($episode->load('deeperLook'));
    }
    
    public function showEpisode(DeeperLookEpisode $deeperLookEpisode)
    {
        return new DeeperLookEpisodeResource($deeperLookEpisode->load('deeperLook'));
    }

    public function getAllEpisodes()
    {
        // REFINEMENT: Using latest() for cleaner code.
        $episodes = DeeperLookEpisode::with('deeperLook')->latest()->get();
        return DeeperLookEpisodeResource::collection($episodes);
    }

    /**
     * UPDATED & REFINED: A more secure and robust update method.
     * It correctly handles all update scenarios while working exclusively with validated data.
     */
    public function update(Request $request, DeeperLook $deeperLook, DeeperLookEpisode $episode)
    {
        // REFINEMENT: The manual ownership check is removed.
        // This is handled by `scopeBindings()` in your route file.

        // REFINEMENT: Validate first, and then work with the validated data array.
        // This is safer than using `$request->only()`. 'sometimes' is ideal for update forms.
        $validatedData = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'video' => 'nullable|file|mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm|max: 1048576',
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => 'nullable|url',
        ]);
        
        // Start with the validated text-based data.
        $updateData = $validatedData;

        // Handle video upload: this takes precedence over a youtube_link
        if ($request->hasFile('video')) {
            if ($episode->video) Storage::disk('public')->delete($episode->video);
            $updateData['video'] = $request->file('video')->store('deeperlooks/episodes/videos', 'public');
            $updateData['youtube_link'] = null; // Clear youtube_link if a video is uploaded
        }
        // Handle a youtube_link update only if a new video was NOT uploaded
        elseif ($request->filled('youtube_link')) {
             if ($episode->video) {
                Storage::disk('public')->delete($episode->video);
                $updateData['video'] = null; // Clear video_path if switching to youtube
            }
        }

        // Handle audio upload separately
        if ($request->hasFile('audio')) {
            if ($episode->audio) Storage::disk('public')->delete($episode->audio);
            $updateData['audio'] = $request->file('audio')->store('deeperlooks/episodes/audios', 'public');
        }

        // Perform the update with all collected data.
        $episode->update($updateData);

        return response()->json([
            'message' => 'Deeper Look episode updated successfully.',
            // REFINEMENT: `refresh()` reloads the model from the DB to ensure the returned data is 100% accurate.
            'data' => new DeeperLookEpisodeResource($episode->refresh())
        ], 200);
    }

    /**
     * Delete an episode.
     */
    public function destroy(DeeperLook $deeperLook, DeeperLookEpisode $episode)
    {
        // REFINEMENT: The manual ownership check is removed (handled by `scopeBindings`).
        if ($episode->video) Storage::disk('public')->delete($episode->video);
        if ($episode->audio) Storage::disk('public')->delete($episode->audio);
        $episode->delete();

        return response()->json(['message' => 'Deeper Look Episode deleted successfully'], 200);
    }

    /**
     * Lock an episode.
     */
    public function lock(DeeperLook $deeperLook, DeeperLookEpisode $episode)
    {
        // REFINEMENT: The manual ownership check is removed (handled by `scopeBindings`).
        $episode->is_locked = true;
        $episode->save();
        return response()->json([
            'message' => 'Deeper Look Episode locked successfully.', 
            'data' => new DeeperLookEpisodeResource($episode)
        ]);
    }

    /**
     * Unlock an episode.
     */
    public function unlock(DeeperLook $deeperLook, DeeperLookEpisode $episode)
    {
        // REFINEMENT: The manual ownership check is removed (handled by `scopeBindings`).
        $episode->is_locked = false;
        $episode->save();
        return response()->json([
            'message' => 'Deeper Look Episode unlocked successfully.', 
            'data' => new DeeperLookEpisodeResource($episode)
        ]);
    }
}