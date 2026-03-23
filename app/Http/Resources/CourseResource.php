<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; // Use the Storage facade for consistency
use App\Http\Traits\ChecksContentAccess;

class CourseResource extends JsonResource
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
        // Determine if the current requester should have full, unrestricted access.
        $hasFullAccess = $this->hasFullAccess();
        // --- END OF FIX ---
        // Determine if the request is from the React Admin panel
        $isAdmin = auth()->guard('admin')->check();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'category' => $this->category,
            'image_path' => $this->image_path ? Storage::disk('public')->url($this->image_path) : null,
            
            // Admins need to see the REAL database value to toggle it in the React panel.
            // Regular users get the dynamically unlocked value to hide the padlock in the Flutter app.
            'is_premium' => $isAdmin ? (bool) $this->is_premium : ((bool) $this->is_premium && !$hasFullAccess),
            'is_locked' => $this->is_premium && !$hasFullAccess,

            'episodes_count' => $this->whenLoaded('episodes', function () {
                return $this->episodes->count();
            }, $this->episodes_count ?? 0),

            'created_at' => $this->created_at->toDateTimeString(),
            'updated_at' => $this->updated_at->toDateTimeString(),
        ];
    }
}