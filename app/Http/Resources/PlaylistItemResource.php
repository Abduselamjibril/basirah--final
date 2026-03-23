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

        // Map model classes to their corresponding Resource classes for secure data transformation.
        $resourceMap = [
            \App\Models\Episode::class               => EpisodeResource::class,
            \App\Models\SurahEpisode::class          => SurahEpisodeResource::class,
            \App\Models\StoryEpisode::class          => StoryEpisodeResource::class,
            \App\Models\CommentaryEpisode::class     => CommentaryEpisodeResource::class,
            \App\Models\DeeperLookEpisode::class     => DeeperLookEpisodeResource::class,
        ];

        // 1. Resolve the appropriate resource for secure data (handling subscription-based nullification).
        $modelClass = get_class($this->playlistable);
        $resourceClass = $resourceMap[$modelClass] ?? null;
        
        // Use the resource to get the secure array, or fallback to raw toArray if not found.
        $episodeData = $resourceClass 
            ? (new $resourceClass($this->playlistable))->toArray($request) 
            : $this->playlistable->toArray();
        
        // 2. Find the short type key (e.g., 'course') from the full class name.
        $typeKey = array_search($modelClass, PlaylistItem::PLAYLISTABLE_TYPES);
        
        // 3. Add the 'type' directly to the array for the frontend.
        if ($typeKey) {
            $episodeData['type'] = $typeKey;
        } else {
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