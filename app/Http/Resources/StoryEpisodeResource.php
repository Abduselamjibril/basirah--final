<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class StoryEpisodeResource extends JsonResource
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

        // An episode is considered locked if its parent Story is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->story->is_premium || $this->is_locked;

        return [
            'id' => $this->id,
            'story_id' => $this->story_id,
            'name' => $this->name,
            'youtube_link' => $this->youtube_link,

            'video' => $this->video ? Storage::disk('public')->url($this->video) : null,
            'audio' => $this->audio ? Storage::disk('public')->url($this->audio) : null,

            // Final lock status for the current requester
            'is_locked' => $isContentGenerallyLocked && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}