<?php

namespace App\Http\Controllers;

use App\Models\SurahEpisode;
use App\Models\Surah;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Http\Resources\SurahEpisodeResource;

class SurahEpisodeController extends Controller
{
    /**
     * Display a listing of the episodes for a specific surah.
     */
    public function index(Surah $surah)
    {
        return SurahEpisodeResource::collection($surah->episodes()->orderBy('created_at', 'asc')->get());
    }

    /**
     * Store a newly created episode in storage for a specific surah.
     */
    public function store(Request $request, Surah $surah)
    {
        // --- THE FIX IS HERE ---
        // 1. Calculate the boolean conditions beforehand.
        $videoIsRequired = !$request->filled('youtube_link');
        $youtubeLinkIsRequired = !$request->hasFile('video');

        // 2. Pass the boolean results directly into the validation rules.
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm', 'max: 1048576', Rule::requiredIf($videoIsRequired)],
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => ['nullable', 'url', Rule::requiredIf($youtubeLinkIsRequired)],
        ]);
        // --- END OF FIX ---

        $videoPath = $request->hasFile('video') ? $request->file('video')->store('surah_episodes/videos', 'public') : null;
        $audioPath = $request->hasFile('audio') ? $request->file('audio')->store('surah_episodes/audios', 'public') : null;

        $episode = $surah->episodes()->create([
            'name' => $validatedData['name'],
            'video' => $videoPath,
            'audio' => $audioPath,
            'youtube_link' => $videoPath ? null : ($validatedData['youtube_link'] ?? null),
            'is_locked' => $surah->is_premium ?? false,
        ]);

        return response()->json([
            'message' => 'Surah episode created successfully.',
            'data' => new SurahEpisodeResource($episode)
        ], 201);
    }

    /**
     * Display the specified episode.
     */
    public function show(Surah $surah, SurahEpisode $episode)
    {
        // This is safe because of scopeBindings() in your route file.
        // If the episode doesn't belong to the surah, Laravel returns a 404.
        return new SurahEpisodeResource($episode);
    }

    /**
     * Update the specified episode in storage.
     */
    public function update(Request $request, Surah $surah, SurahEpisode $episode)
    {
        // scopeBindings() in the route file makes this manual check unnecessary.
        
        $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'video' => 'nullable|file|mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm|max: 1048576',
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => 'nullable|url',
        ]);

        $updateData = $request->only('name', 'youtube_link');

        if ($request->hasFile('video')) {
            if ($episode->video) {
                Storage::disk('public')->delete($episode->video);
            }
            $updateData['video'] = $request->file('video')->store('surah_episodes/videos', 'public');
            $updateData['youtube_link'] = null;
        }

        if ($request->hasFile('audio')) {
            if ($episode->audio) {
                Storage::disk('public')->delete($episode->audio);
            }
            $updateData['audio'] = $request->file('audio')->store('surah_episodes/audios', 'public');
        }

        $episode->update($updateData);

        return response()->json([
            'message' => 'Surah episode updated successfully.',
            'data' => new SurahEpisodeResource($episode->refresh())
        ], 200);
    }

    /**
     * Remove the specified episode from storage.
     */
    public function destroy(Surah $surah, SurahEpisode $episode)
    {
        // scopeBindings() in the route file makes this manual check unnecessary.
        
        if ($episode->video) {
            Storage::disk('public')->delete($episode->video);
        }
        if ($episode->audio) {
            Storage::disk('public')->delete($episode->audio);
        }
        $episode->delete();

        return response()->json(['message' => 'Surah Episode deleted successfully'], 200);
    }

    /**
     * Lock the specified episode.
     */
    public function lock(Surah $surah, SurahEpisode $episode)
    {
        // scopeBindings() in the route file makes this manual check unnecessary.
        $episode->is_locked = true;
        $episode->save();

        return response()->json([
            'message' => 'Surah Episode locked successfully.',
            'data' => new SurahEpisodeResource($episode)
        ]);
    }

    /**
     * Unlock the specified episode.
     */
    public function unlock(Surah $surah, SurahEpisode $episode)
    {
        // scopeBindings() in the route file makes this manual check unnecessary.
        $episode->is_locked = false;
        $episode->save();

        return response()->json([
            'message' => 'Surah Episode unlocked successfully.',
            'data' => new SurahEpisodeResource($episode)
        ]);
    }
}