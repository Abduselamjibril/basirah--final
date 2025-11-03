<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class EpisodeResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // --- START OF FIX ---
        $hasFullAccess = false;
        if (auth()->guard('admin')->check()) {
            $hasFullAccess = true;
        } elseif (auth()->guard('sanctum')->check()) {
            $user = auth()->guard('sanctum')->user();
            $hasFullAccess = $user ? $user->isSubscribedAndActive() : false;
        }
        // --- END OF FIX ---

        // An episode is considered locked if its parent course is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->course->is_premium || $this->is_locked;

        return [
            'id' => $this->id,
            'course_id' => $this->course_id,
            'title' => $this->title,
            'youtube_link' => $this->youtube_link,

            'video_path' => $this->video_path ? Storage::disk('public')->url($this->video_path) : null,
            'audio_path' => $this->audio_path ? Storage::disk('public')->url($this->audio_path) : null,
            
            // The final lock status for the current requester.
            'is_locked' => $isContentGenerallyLocked && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}