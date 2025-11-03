<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PlaylistResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'created_at' => $this->created_at->toIso8601String(),
            // Only include 'items_count' if it was loaded (e.g., in the index method)
            'items_count' => $this->whenCounted('items'),
            // Only include the full 'items' array if it was loaded (e.g., in the show method)
            'items' => PlaylistItemResource::collection($this->whenLoaded('items')),
        ];
    }
}