<?php

namespace App\Http\Traits;

trait ChecksContentAccess
{
    /**
     * Determine if the current user has full access to premium content.
     * This checks if the user is an admin or is an active, subscribed user.
     *
     * @return bool
     */
    protected function hasFullAccess(): bool
    {
        if (auth()->guard('admin')->check()) {
            return true;
        }

        if (auth()->guard('sanctum')->check()) {
            $user = auth()->guard('sanctum')->user();
            return $user ? $user->isSubscribedAndActive() : false;
        }

        return false;
    }
}
