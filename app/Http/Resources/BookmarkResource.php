<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BookmarkResource extends JsonResource
{
    /**
     * Maps model classes to their corresponding Resource classes.
     */
    private const RESOURCE_MAP = [
        \App\Models\Course::class                => CourseResource::class,
        \App\Models\Story::class                 => StoryResource::class,
        \App\Models\Surah::class                 => SurahResource::class,
        \App\Models\DeeperLook::class            => DeeperLookResource::class,
        \App\Models\Commentary::class            => CommentaryResource::class,
        \App\Models\Episode::class               => EpisodeResource::class,
        \App\Models\StoryEpisode::class          => StoryEpisodeResource::class,
        \App\Models\SurahEpisode::class          => SurahEpisodeResource::class,
        \App\Models\DeeperLookEpisode::class     => DeeperLookEpisodeResource::class,
        \App\Models\CommentaryEpisode::class     => CommentaryEpisodeResource::class,
    ];

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bookmarkable_id' => $this->bookmarkable_id,
            'bookmarkable_type' => $this->bookmarkable_type,
            'created_at' => $this->created_at,
            'bookmarkable' => $this->resolveResource(),
        ];
    }

    /**
     * Dynamically resolves the appropriate resource for the bookmarked content.
     */
    protected function resolveResource()
    {
        if (!$this->bookmarkable) {
            return null;
        }

        $modelClass = get_class($this->bookmarkable);
        $resourceClass = self::RESOURCE_MAP[$modelClass] ?? null;

        if ($resourceClass) {
            return new $resourceClass($this->bookmarkable);
        }

        // Fallback to raw data if no resource is mapped (shouldn't happen for core content)
        return $this->bookmarkable;
    }
}
