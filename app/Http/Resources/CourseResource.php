<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; // Use the Storage facade for consistency

class CourseResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // --- START OF FIX ---
        // Determine if the current requester should have full, unrestricted access.
        $hasFullAccess = false;
        if (auth()->guard('admin')->check()) {
            // Admins always have full access.
            $hasFullAccess = true;
        } elseif (auth()->guard('sanctum')->check()) {
            // For regular users, check their subscription status.
            $user = auth()->guard('sanctum')->user();
            $hasFullAccess = ($user instanceof \App\Models\User) ? $user->isSubscribedAndActive() : false;
        }
        // --- END OF FIX ---

        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'category' => $this->category,
            'image_path' => $this->image_path ? Storage::disk('public')->url($this->image_path) : null,

            // Provide both the raw premium status and the dynamic locked status.
            // 'is_premium' is for the admin panel's toggles.
            'is_premium' => (bool) $this->is_premium,
            // 'is_locked' is for the user app to dynamically show locked content.
            'is_locked' => $this->is_premium && !$hasFullAccess,

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}
