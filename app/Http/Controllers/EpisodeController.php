<?php

namespace App\Http\Controllers;

use App\Models\Course;
use App\Models\Episode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Http\Resources\EpisodeResource;

class EpisodeController extends Controller
{
    // ... index, store, show, showById methods are unchanged ...
    public function index($courseId)
    {
        $course = Course::with('episodes')->findOrFail($courseId);
        return EpisodeResource::collection($course->episodes);
    }

    public function store(Request $request, $courseId)
    {
        $course = Course::findOrFail($courseId);
        $validatedData = $request->validate([
            'title' => 'required|string|max:255',
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm', 'max: 1048576', Rule::requiredIf(fn() => !$request->filled('youtube_link'))],
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => ['nullable', 'url', Rule::requiredIf(fn() => !$request->hasFile('video'))],
        ]);
        $videoPath = $request->hasFile('video') ? $request->file('video')->store('episodes/videos', 'public') : null;
        $audioPath = $request->hasFile('audio') ? $request->file('audio')->store('episodes/audios', 'public') : null;
        $episode = $course->episodes()->create([
            'title' => $validatedData['title'],
            'video_path' => $videoPath,
            'audio_path' => $audioPath,
            'youtube_link' => $videoPath ? null : ($validatedData['youtube_link'] ?? null),
            'is_locked' => $course->is_premium,
        ]);
        return response()->json(['message' => 'Episode created successfully.', 'data' => new EpisodeResource($episode)], 201);
    }

    public function show($courseId, $episodeId)
    {
        $episode = Episode::where('course_id', $courseId)->findOrFail($episodeId);
        return new EpisodeResource($episode);
    }

    public function showById($episodeId)
    {
        $episode = Episode::findOrFail($episodeId);
        return new EpisodeResource($episode);
    }

    /**
     *  FIXED AND REFACTORED UPDATE METHOD
     */
    public function update(Request $request, $courseId, $episodeId)
    {
        $episode = Episode::where('course_id', $courseId)->findOrFail($episodeId);

        $validatedData = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'video' => 'nullable|file|mimetypes:video/mp4,video/avi,video/mpeg,video/quicktime,video/webm|max: 1048576',
            'audio' => 'nullable|file|mimetypes:audio/mpeg,audio/mp3,audio/wav,audio/ogg|max: 1048576',
            'youtube_link' => 'nullable|url',
        ]);

        // Start with the text-based data that was validated.
        $updateData = $request->only(['title', 'youtube_link']);

        // Handle video upload: this takes precedence over a youtube_link
        if ($request->hasFile('video')) {
            // Delete the old video file if it exists
            if ($episode->video_path) {
                Storage::disk('public')->delete($episode->video_path);
            }
            // Store the new video and update the data for the model
            $updateData['video_path'] = $request->file('video')->store('episodes/videos', 'public');
            // Ensure youtube_link is cleared if a video is uploaded
            $updateData['youtube_link'] = null;
        } 
        // Handle a youtube_link update only if a new video was NOT uploaded
        elseif ($request->filled('youtube_link')) {
             // If we're switching to a YouTube link, delete the old video file
             if ($episode->video_path) {
                Storage::disk('public')->delete($episode->video_path);
                $updateData['video_path'] = null;
            }
        }
        
        // Handle audio upload separately
        if ($request->hasFile('audio')) {
            // Delete the old audio file if it exists
            if ($episode->audio_path) {
                Storage::disk('public')->delete($episode->audio_path);
            }
            // Store the new audio file
            $updateData['audio_path'] = $request->file('audio')->store('episodes/audios', 'public');
        }

        // Perform the update with all collected data.
        // This only runs an UPDATE query if data has actually changed.
        $episode->update($updateData);

        return response()->json([
            'message' => 'Episode updated successfully.', 
            'data' => new EpisodeResource($episode->refresh())
        ], 200);
    }

    // ... destroy, lock, unlock, lockAll, unlockAll methods are unchanged ...
    public function destroy($courseId, $episodeId)
    {
        $episode = Episode::where('course_id', $courseId)->findOrFail($episodeId);
        try {
            if ($episode->video_path && Storage::disk('public')->exists($episode->video_path)) Storage::disk('public')->delete($episode->video_path);
            if ($episode->audio_path && Storage::disk('public')->exists($episode->audio_path)) Storage::disk('public')->delete($episode->audio_path);
        } catch (\Exception $e) {
            Log::error("Error deleting files for episode ID {$episodeId}: " . $e->getMessage());
        }
        $episode->delete();
        return response()->json(['message' => 'Episode deleted successfully.'], 200);
    }

    public function lock($courseId, $episodeId)
    {
        $episode = Episode::where('course_id', $courseId)->findOrFail($episodeId);
        $episode->is_locked = true;
        $episode->save();
        return response()->json(['message' => 'Episode locked.', 'data' => new EpisodeResource($episode)]);
    }

    public function unlock($courseId, $episodeId)
    {
        $episode = Episode::where('course_id', $courseId)->findOrFail($episodeId);
        $episode->is_locked = false;
        $episode->save();
        return response()->json(['message' => 'Episode unlocked.', 'data' => new EpisodeResource($episode)]);
    }

    public function lockAll($courseId)
    {
        $course = Course::findOrFail($courseId);
        $course->episodes()->update(['is_locked' => true]);
        return response()->json(['message' => 'All episodes for the course have been locked.']);
    }

    public function unlockAll($courseId)
    {
        $course = Course::findOrFail($courseId);
        $course->episodes()->update(['is_locked' => false]);
        return response()->json(['message' => 'All episodes for the course have been unlocked.']);
    }
}