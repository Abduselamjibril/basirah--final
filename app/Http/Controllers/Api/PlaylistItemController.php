<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PlaylistResource;
use App\Models\Playlist;
use App\Models\PlaylistItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
// We are removing the 'AuthorizesRequests' trait, so this import is no longer needed.
// use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class PlaylistItemController extends Controller
{
    // The 'AuthorizesRequests' trait is removed as we are replacing its methods.
    // use AuthorizesRequests;

    public function store(Request $request, Playlist $playlist)
    {
        // --- FIX APPLIED: Reverted to a manual authorization check ---
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        $validated = $request->validate([
            'episode_id' => 'required|integer',
            'type' => ['required', 'string', Rule::in(array_keys(PlaylistItem::PLAYLISTABLE_TYPES))],
        ]);
        
        $modelClass = PlaylistItem::PLAYLISTABLE_TYPES[$validated['type']];

        if (! $modelClass::where('id', $validated['episode_id'])->exists()) {
             throw ValidationException::withMessages(['episode_id' => 'The selected episode does not exist.']);
        }
        
        $itemExists = $playlist->items()
            ->where('playlistable_id', $validated['episode_id'])
            ->where('playlistable_type', $modelClass)
            ->exists();

        if ($itemExists) {
            return new PlaylistResource($playlist->fresh()->load('items.playlistable'));
        }
        
        $maxOrder = $playlist->items()->max('order') ?? 0;

        $playlist->items()->create([
            'playlistable_id' => $validated['episode_id'],
            'playlistable_type' => $modelClass,
            'order' => $maxOrder + 1,
        ]);

        return new PlaylistResource($playlist->fresh()->load('items.playlistable'));
    }

    public function destroy(Request $request, Playlist $playlist, PlaylistItem $playlistItem)
    {
        // --- FIX APPLIED: Reverted to a manual authorization check ---
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        if ((int)$playlistItem->playlist_id !== (int)$playlist->id) {
            abort(403, 'This item does not belong to the specified playlist.');
        }

        $playlistItem->delete();
        
        return response()->json(['message' => 'Item removed from playlist successfully.']);
    }

    public function reorder(Request $request, Playlist $playlist)
    {
        // --- FIX APPLIED: Reverted to a manual authorization check ---
        if ((int)$request->user()->id !== (int)$playlist->user_id) {
            abort(403, 'Unauthorized action.');
        }

        $validated = $request->validate([
            'item_ids' => 'required|array',
            'item_ids.*' => [
                'required',
                'integer',
                Rule::exists('playlist_items', 'id')->where('playlist_id', $playlist->id),
            ],
        ]);
        
        DB::transaction(function () use ($validated) {
            foreach ($validated['item_ids'] as $index => $itemId) {
                PlaylistItem::where('id', $itemId)
                           ->update(['order' => $index + 1]);
            }
        });

        return new PlaylistResource($playlist->fresh()->load('items.playlistable'));
    }
}