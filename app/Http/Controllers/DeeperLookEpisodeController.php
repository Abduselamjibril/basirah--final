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
            /**
             * @OA\Get(
             *     path="/deeper-looks/{deeperLook}/episodes",
             *     summary="Get all episodes for a specific Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="List of episodes")
             * )
             */
        // REFINEMENT: Using latest() is a more expressive alias for orderBy('created_at', 'desc').
        return DeeperLookEpisodeResource::collection($deeperLook->episodes()->with('deeperLook')->latest()->get());
    }

    /**
     * Store a newly created episode.
     */
    public function store(Request $request, DeeperLook $deeperLook)
    {
            /**
             * @OA\Post(
             *     path="/deeper-looks/{deeperLook}/episodes",
             *     summary="Create a new episode for a specific Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
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
             *     @OA\Response(response=201, description="Deeper Look episode created successfully."),
             *     @OA\Response(response=422, description="Validation error")
             * )
             */
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
            /**
             * @OA\Get(
             *     path="/deeper-looks/{deeperLook}/episodes/{episode}",
             *     summary="Get a specific episode for a Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Parameter(
             *         name="episode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="Episode found")
             * )
             */
        // REFINEMENT: The manual ownership check is removed.
        // `scopeBindings()` in your route file handles this security check automatically.
        // If the episode doesn't belong to the deeperLook, Laravel returns a 404.
        return new DeeperLookEpisodeResource($episode->load('deeperLook'));
    }

    public function showEpisode(DeeperLookEpisode $deeperLookEpisode)
    {
            /**
             * @OA\Get(
             *     path="/deeper-look-episodes/{deeperLookEpisode}",
             *     summary="Get a specific episode by ID",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLookEpisode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="Episode found")
             * )
             */
        return new DeeperLookEpisodeResource($deeperLookEpisode->load('deeperLook'));
    }

    public function getAllEpisodes()
    {
            /**
             * @OA\Get(
             *     path="/deeper-look-episodes",
             *     summary="Get all deeper look episodes",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Response(response=200, description="List of deeper look episodes")
             * )
             */
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
            /**
             * @OA\Put(
             *     path="/deeper-looks/{deeperLook}/episodes/{episode}",
             *     summary="Update a specific episode for a Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Parameter(
             *         name="episode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
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
             *     @OA\Response(response=200, description="Deeper Look episode updated successfully."),
             *     @OA\Response(response=404, description="Episode not found.")
             * )
             */
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
            /**
             * @OA\Delete(
             *     path="/deeper-looks/{deeperLook}/episodes/{episode}",
             *     summary="Delete a specific episode for a Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Parameter(
             *         name="episode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="Deeper Look Episode deleted successfully"),
             *     @OA\Response(response=404, description="Episode not found.")
             * )
             */
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
            /**
             * @OA\Patch(
             *     path="/deeper-looks/{deeperLook}/episodes/{episode}/lock",
             *     summary="Lock a specific episode for a Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Parameter(
             *         name="episode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="Deeper Look Episode locked successfully."),
             *     @OA\Response(response=404, description="Episode not found.")
             * )
             */
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
            /**
             * @OA\Patch(
             *     path="/deeper-looks/{deeperLook}/episodes/{episode}/unlock",
             *     summary="Unlock a specific episode for a Deeper Look",
             *     tags={"DeeperLookEpisode"},
             *     @OA\Parameter(
             *         name="deeperLook",
             *         in="path",
             *         required=true,
             *         description="Deeper Look ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Parameter(
             *         name="episode",
             *         in="path",
             *         required=true,
             *         description="Episode ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\Response(response=200, description="Deeper Look Episode unlocked successfully."),
             *     @OA\Response(response=404, description="Episode not found.")
             * )
             */
        // REFINEMENT: The manual ownership check is removed (handled by `scopeBindings`).
        $episode->is_locked = false;
        $episode->save();
        return response()->json([
            'message' => 'Deeper Look Episode unlocked successfully.',
            'data' => new DeeperLookEpisodeResource($episode)
        ]);
    }
}
