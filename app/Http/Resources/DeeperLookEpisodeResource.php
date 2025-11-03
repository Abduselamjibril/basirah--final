<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class DeeperLookEpisodeResource extends JsonResource
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

        // An episode is considered locked if its parent DeeperLook is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->deeperLook->is_premium || $this->is_locked;

        return [
            'id' => $this->id,
            'deeper_look_id' => $this->deeper_look_id,
            'name' => $this->name, // Note: Your DB field is 'name' not 'title'
            'youtube_link' => $this->youtube_link,

            'video' => $this->video ? Storage::disk('public')->url($this->video) : null,
            'audio' => $this->audio ? Storage::disk('public')->url($this->audio) : null,

            'is_locked' => $isContentGenerallyLocked && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}