<?php
// app/Models/Concerns/Bookmarkable.php

namespace App\Models\Concerns;

use App\Models\Bookmark;
use Illuminate\Database\Eloquent\Relations\MorphMany;

trait Bookmarkable
{
    /**
     * Get all the bookmarks for this model.
     */
    public function bookmarks(): MorphMany
    {
        return $this->morphMany(Bookmark::class, 'bookmarkable');
    }

    /**
     * An optional helper to check if the current model is bookmarked by a given user.
     *
     * @param \App\Models\User $user
     * @return bool
     */
    public function isBookmarkedBy($user): bool
    {
        if (!$user) {
            return false;
        }
        
        // This checks if the relationship exists without loading all bookmarks from the DB.
        return $this->bookmarks()->where('phone_number', $user->phone_number)->exists();
    }
}