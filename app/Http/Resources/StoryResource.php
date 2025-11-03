<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; // Use Storage facade

class StoryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // --- YOUR ORIGINAL LOGIC IS 100% PRESERVED ---
        $hasFullAccess = false;
        if (auth()->guard('admin')->check()) {
            $hasFullAccess = true;
        } elseif (auth()->guard('sanctum')->check()) {
            $user = auth()->guard('sanctum')->user();
            $hasFullAccess = $user ? $user->isSubscribedAndActive() : false;
        }
        // --- YOUR ORIGINAL LOGIC IS 100% PRESERVED ---

        return [
            // --- ALL YOUR ORIGINAL FIELDS ARE PRESERVED ---
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'image' => $this->image ? Storage::disk('public')->url($this->image) : null,

            // Raw premium status for the admin panel
            'is_premium' => (bool) $this->is_premium,
            // Dynamic locked status for the user app (using your original logic)
            'is_locked' => $this->is_premium && !$hasFullAccess,

            // --- THIS IS THE ONLY ADDITION ---
            // The count is added here. It relies on `withCount('storyEpisodes')` in the controller.
            'story_episodes_count' => $this->when(isset($this->story_episodes_count), $this->story_episodes_count, 0),
            // --- END OF ADDITION ---

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),

            // Your relationship is also preserved
            'storyEpisodes' => StoryEpisodeResource::collection($this->whenLoaded('storyEpisodes')),
        ];
    }
}