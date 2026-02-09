<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class SurahEpisodeResource extends JsonResource
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
            $hasFullAccess = ($user instanceof \App\Models\User) ? $user->isSubscribedAndActive() : false;
        }
        // --- END OF FIX ---

        // An episode is considered locked if its parent Surah is premium OR it is individually locked.
        $isContentGenerallyLocked = $this->surah->is_premium || $this->is_locked;

        return [
            'id' => $this->id,
            'surah_id' => $this->surah_id,
            'name' => $this->name,
            'youtube_link' => $this->youtube_link,

            'video' => $this->video ? Storage::disk('public')->url($this->video) : null,
            'audio' => $this->audio ? Storage::disk('public')->url($this->audio) : null,

            'is_locked' => $isContentGenerallyLocked && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}
