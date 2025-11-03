<?php

namespace App\Http\Controllers;

use App\Models\Commentary;
use App\Models\CommentaryEpisode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Http\Resources\CommentaryEpisodeResource;

class CommentaryEpisodeController extends Controller
{
    /**
     * Display a listing of the episodes for a specific commentary.
     */
    public function index(Commentary $commentary)
    {
        // Using the resource to transform the collection, ordered by creation date.
        return CommentaryEpisodeResource::collection($commentary->episodes()->orderBy('created_at', 'asc')->get());
    }

    /**
     * Store a newly created episode in storage for a specific commentary.
     */
    public function store(Request $request, Commentary $commentary)
    {
        $validatedData = $request->validate([
            'title' => 'required|string|max:255',
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm', 'max: 1048576', Rule::requiredIf(fn() => !$request->filled('youtube_link'))],
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => ['nullable', 'url', Rule::requiredIf(fn() => !$request->hasFile('video'))],
        ]);

        $videoPath = $request->hasFile('video') ? $request->file('video')->store('commentary_episodes/videos', 'public') : null;
        $audioPath = $request->hasFile('audio') ? $request->file('audio')->store('commentary_episodes/audios', 'public') : null;

        $episode = $commentary->episodes()->create([
            'title' => $validatedData['title'],
            'video' => $videoPath,
            'audio' => $audioPath,
            'youtube_link' => $videoPath ? null : ($validatedData['youtube_link'] ?? null),
            // New episodes inherit their locked status from the parent commentary.
            'is_locked' => $commentary->is_premium,
        ]);

        return response()->json([
            'message' => 'Commentary episode created successfully.',
            'data' => new CommentaryEpisodeResource($episode)
        ], 201);
    }

    /**
     * Display the specified episode.
     * The check to see if the episode belongs to the commentary is now handled by scopeBindings() in the route.
     */
    public function show(Commentary $commentary, CommentaryEpisode $episode)
    {
        return new CommentaryEpisodeResource($episode);
    }

    /**
     * Update the specified episode in storage.
     * The check to see if the episode belongs to the commentary is now handled by scopeBindings() in the route.
     */
    public function update(Request $request, Commentary $commentary, CommentaryEpisode $episode)
    {
        $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'video' => 'nullable|file|mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm|max: 1048576',
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => 'nullable|url',
        ]);

        $updateData = $request->only('title', 'youtube_link');

        if ($request->hasFile('video')) {
            if ($episode->video) {
                Storage::disk('public')->delete($episode->video);
            }
            $updateData['video'] = $request->file('video')->store('commentary_episodes/videos', 'public');
            $updateData['youtube_link'] = null; // A new video file upload overrides any YouTube link.
        }

        if ($request->hasFile('audio')) {
            if ($episode->audio) {
                Storage::disk('public')->delete($episode->audio);
            }
            $updateData['audio'] = $request->file('audio')->store('commentary_episodes/audios', 'public');
        }

        $episode->update($updateData);

        return response()->json([
            'message' => 'Commentary episode updated successfully.',
            'data' => new CommentaryEpisodeResource($episode->refresh())
        ], 200);
    }

    /**
     * Remove the specified episode from storage.
     * The check to see if the episode belongs to the commentary is now handled by scopeBindings() in the route.
     */
    public function destroy(Commentary $commentary, CommentaryEpisode $episode)
    {
        if ($episode->video) {
            Storage::disk('public')->delete($episode->video);
        }
        if ($episode->audio) {
            Storage::disk('public')->delete($episode->audio);
        }
        $episode->delete();

        return response()->json(['message' => 'Commentary Episode deleted successfully'], 200);
    }

    /**
     * Lock the specified episode.
     * The check to see if the episode belongs to the commentary is now handled by scopeBindings() in the route.
     */
    public function lock(Commentary $commentary, CommentaryEpisode $episode)
    {
        $episode->is_locked = true;
        $episode->save();

        return response()->json([
            'message' => 'Commentary Episode locked successfully.',
            'data' => new CommentaryEpisodeResource($episode)
        ]);
    }

    /**
     * Unlock the specified episode.
     * The check to see if the episode belongs to the commentary is now handled by scopeBindings() in the route.
     */
    public function unlock(Commentary $commentary, CommentaryEpisode $episode)
    {
        $episode->is_locked = false;
        $episode->save();

        return response()->json([
            'message' => 'Commentary Episode unlocked successfully.',
            'data' => new CommentaryEpisodeResource($episode)
        ]);
    }
}