<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; // Use Storage facade
use App\Http\Traits\ChecksContentAccess;

class CommentaryEpisodeResource extends JsonResource
{
    use ChecksContentAccess;
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // --- START OF FIX ---
        // Consistent logic to check for full access
        $hasFullAccess = $this->hasFullAccess();
        // --- END OF FIX ---

        // An episode is considered locked if its parent Commentary is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->commentary->is_premium || $this->is_locked;
        $isLockedForUser = $isContentGenerallyLocked && !$hasFullAccess;

        return [
            'id' => $this->id,
            'commentary_id' => $this->commentary_id,
            'title' => $this->title,
            
            'youtube_link' => $isLockedForUser ? null : $this->youtube_link,
            'video' => $isLockedForUser ? null : ($this->video ? Storage::disk('public')->url($this->video) : null),
            'audio' => $isLockedForUser ? null : ($this->audio ? Storage::disk('public')->url($this->audio) : null),

            // The final lock status for the current user
            'is_locked' => $isLockedForUser,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}