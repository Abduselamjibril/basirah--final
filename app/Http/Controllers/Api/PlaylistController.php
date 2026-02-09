<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PlaylistResource;
use App\Models\Playlist;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
// We are removing the 'AuthorizesRequests' trait, so this import is no longer needed.
// use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class PlaylistController extends Controller
{
    // The 'AuthorizesRequests' trait is removed as we are replacing all its methods.
    // use AuthorizesRequests;

    /**
     * Display a listing of the authenticated user's playlists.
     */
        /**
         * @OA\Get(
         *     path="/playlists",
         *     summary="List authenticated user's playlists",
         *     tags={"Playlist"},
         *     @OA\Response(response=200, description="List of playlists")
         * )
         */
    public function index(Request $request)
    {
        $playlists = $request->user()
            ->playlists()
            ->withCount('items')
            ->latest()
            ->get();

        return PlaylistResource::collection($playlists);
    }

    /**
     * Store a newly created playlist in storage for the authenticated user.
     */
        /**
         * @OA\Post(
         *     path="/playlists",
         *     summary="Create a new playlist",
         *     tags={"Playlist"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name"},
         *             @OA\Property(property="name", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Playlist created")
         * )
         */
    public function store(Request $request)
    {
        $validated = $request->validate(['name' => 'required|string|max:255']);

        $playlist = $request->user()->playlists()->create($validated);

        return new PlaylistResource($playlist->load('items'));
    }

    /**
     * Display the specified playlist if the user is authorized.
     */
        /**
         * @OA\Get(
         *     path="/playlists/{playlist}",
         *     summary="Show a playlist",
         *     tags={"Playlist"},
         *     @OA\Parameter(
         *         name="playlist",
         *         in="path",
         *         required=true,
         *         description="Playlist ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Playlist details")
         * )
         */
    public function show(Request $request, Playlist $playlist)
    {
        // Manual authorization check
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        $playlist->load('items.playlistable');

        return new PlaylistResource($playlist);
    }

    /**
     * Update the specified playlist in storage if the user is authorized.
     */
        /**
         * @OA\Put(
         *     path="/playlists/{playlist}",
         *     summary="Update a playlist",
         *     tags={"Playlist"},
         *     @OA\Parameter(
         *         name="playlist",
         *         in="path",
         *         required=true,
         *         description="Playlist ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name"},
         *             @OA\Property(property="name", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Playlist updated")
         * )
         */
    public function update(Request $request, Playlist $playlist)
    {
        // --- FIX APPLIED: Reverted to a manual check ---
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        $validated = $request->validate(['name' => 'required|string|max:255']);
        $playlist->update($validated);

        return new PlaylistResource($playlist->load('items.playlistable'));
    }

    /**
     * Remove the specified playlist from storage if the user is authorized.
     */
        /**
         * @OA\Delete(
         *     path="/playlists/{playlist}",
         *     summary="Delete a playlist",
         *     tags={"Playlist"},
         *     @OA\Parameter(
         *         name="playlist",
         *         in="path",
         *         required=true,
         *         description="Playlist ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=204, description="Playlist deleted")
         * )
         */
    public function destroy(Request $request, Playlist $playlist)
    {
        // --- FIX APPLIED: Reverted to a manual check ---
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        $playlist->delete();

        return response()->json(null, Response::HTTP_NO_CONTENT);
    }
}
