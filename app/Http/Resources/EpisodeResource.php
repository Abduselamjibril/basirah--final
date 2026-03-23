<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;
use App\Http\Traits\ChecksContentAccess;

class EpisodeResource extends JsonResource
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
        $hasFullAccess = $this->hasFullAccess();
        // --- END OF FIX ---

        // An episode is considered locked if its parent course is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->course->is_premium || $this->is_locked;
        $isLockedForUser = $isContentGenerallyLocked && !$hasFullAccess;

        return [
            'id' => $this->id,
            'course_id' => $this->course_id,
            'title' => $this->title,
            
            // Only output media fields if the user has access
            'youtube_link' => $isLockedForUser ? null : $this->youtube_link,
            'video_path' => $isLockedForUser ? null : ($this->video_path ? Storage::disk('public')->url($this->video_path) : null),
            'audio_path' => $isLockedForUser ? null : ($this->audio_path ? Storage::disk('public')->url($this->audio_path) : null),
            
            // The final lock status for the current requester.
            'is_locked' => $isLockedForUser,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}