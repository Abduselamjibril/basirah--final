<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class DeeperLookResource extends JsonResource
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

        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'image' => $this->image ? Storage::disk('public')->url($this->image) : null,

            'is_premium' => (bool) $this->is_premium,
            'is_locked' => $this->is_premium && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),

            'episodes' => DeeperLookEpisodeResource::collection($this->whenLoaded('episodes')),
        ];
    }
}
