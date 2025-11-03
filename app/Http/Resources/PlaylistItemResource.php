<?php

namespace App\Http\Resources;

use App\Models\PlaylistItem; 
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PlaylistItemResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array
     */
    public function toArray(Request $request): array
    {
        // This part is correct and handles episodes that have been deleted.
        if (is_null($this->playlistable)) {
            return [
                'item_id' => $this->id,
                'order' => $this->order,
                'episode' => null, // Indicate that the episode data is missing
                'type' => 'deleted', // Add a type to help the frontend identify it
            ];
        }

        // --- THE FIX IS APPLIED BELOW ---

        // 1. Convert the loaded episode model (e.g., Episode, SurahEpisode) into a plain PHP array.
        // The `$this->playlistable` holds the actual model object.
        $episodeData = $this->playlistable->toArray();
        
        // 2. Find the short type key (e.g., 'course') from the full class name. This is correct.
        $typeKey = array_search(get_class($this->playlistable), PlaylistItem::PLAYLISTABLE_TYPES);
        
        // 3. Add the 'type' directly to the PHP array. This is the correct way to do it.
        if ($typeKey) {
            $episodeData['type'] = $typeKey;
        } else {
            // Add a fallback for safety
            $episodeData['type'] = 'unknown';
        }
        
        // --- END FIX ---

        return [
            'item_id' => $this->id,
            'order' => $this->order,
            // Now, we return the modified $episodeData array, which will be converted to a JSON object.
            'episode' => $episodeData,
        ];
    }
}