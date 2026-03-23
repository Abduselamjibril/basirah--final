<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;
use App\Http\Traits\ChecksContentAccess;

class DeeperLookResource extends JsonResource
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
        // Determine if the request is from the React Admin panel
        $isAdmin = auth()->guard('admin')->check();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'image' => $this->image ? Storage::disk('public')->url($this->image) : null,
            
            // Admins need to see the REAL database value to toggle it in the React panel.
            'is_premium' => $isAdmin ? (bool) $this->is_premium : ((bool) $this->is_premium && !$hasFullAccess),
            'is_locked' => $this->is_premium && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),

            'episodes' => DeeperLookEpisodeResource::collection($this->whenLoaded('episodes')),
        ];
    }
}