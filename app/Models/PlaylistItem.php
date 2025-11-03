<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class PlaylistItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'playlist_id',
        'playlistable_id',
        'playlistable_type',
        'order',
    ];

    /**
     * A map of playlistable types to their corresponding model classes.
     * THIS IS THE MISSING CONSTANT.
     */
    public const PLAYLISTABLE_TYPES = [
        'course' => \App\Models\Episode::class,
        'surah' => \App\Models\SurahEpisode::class,
        'story' => \App\Models\StoryEpisode::class,
        'commentary' => \App\Models\CommentaryEpisode::class,
        'deeper_look' => \App\Models\DeeperLookEpisode::class,
    ];

    /**
     * Get the parent playlistable model (Episode, SurahEpisode, etc.).
     */
    public function playlistable(): MorphTo
    {
        return $this->morphTo();
    }
}