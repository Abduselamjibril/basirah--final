<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; // Use Storage facade for consistency

class CommentaryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // --- START OF FIX ---
        // Check which guard is active to determine subscription status
        $hasFullAccess = false;
        if (auth()->guard('admin')->check()) {
            // If an admin is logged in, they always have full access.
            $hasFullAccess = true;
        } elseif (auth()->guard('sanctum')->check()) {
            // If a user is logged in, check their subscription.
            $user = auth()->guard('sanctum')->user();
            $hasFullAccess = ($user instanceof \App\Models\User) ? $user->isSubscribedAndActive() : false;
        }
        // --- END OF FIX ---

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'image' => $this->image ? Storage::disk('public')->url($this->image) : null,

            // Correctly determine the final lock status based on full access
            'is_premium' => $this->is_premium, // The raw premium status for the admin panel
            'is_locked' => $this->is_premium && !$hasFullAccess, // The dynamic status for the user app

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),

            // Include episodes only when they are loaded
            'episodes' => CommentaryEpisodeResource::collection($this->whenLoaded('episodes')),
        ];
    }
}
