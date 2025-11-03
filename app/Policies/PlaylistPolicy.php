<?php

namespace App\Policies;

use App\Models\Playlist;
use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;
use Illuminate\Support\Facades\Log;
class PlaylistPolicy
{
    use HandlesAuthorization;

    /**
     * Determine whether the user can view the model.
     * This will be used for the show() method.
     */
    public function view(User $user, Playlist $playlist): bool
    {
         Log::info("Policy Check: Attempting to view playlist #" . $playlist->id . " (owned by user #" . $playlist->user_id . ") as authenticated user #" . $user->id);
        return $user->id === $playlist->user_id;
    }

    /**
     * Determine whether the user can update the model.
     * We will use this for updating the playlist's name, adding items,
     * reordering items, and deleting items.
     */
    public function update(User $user, Playlist $playlist): bool
    {
        return $user->id === $playlist->user_id;
    }

    /**
     * Determine whether the user can delete the model.
     * This will be used for deleting an entire playlist.
     */
    public function delete(User $user, Playlist $playlist): bool
    {
        return $user->id === $playlist->user_id;
    }
}