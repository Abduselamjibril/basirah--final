<?php

namespace App\Models;

// --- ADDED ---
use App\Models\Playlist;
use Illuminate\Database\Eloquent\Relations\MorphToMany;
// --- END ADDED ---

use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StoryEpisode extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'story_id',
        'name',
        'video',
        'audio',
        'youtube_link',
        'is_locked',
    ];

    public function story()
    {
        return $this->belongsTo(Story::class);
    }

    // --- ADDED: The Polymorphic Relationship ---
    /**
     * Get all of the playlists that this episode is a part of.
     */
    public function playlists(): MorphToMany
    {
        return $this->morphToMany(Playlist::class, 'playlistable', 'playlist_items');
    }
    // --- END ADDED ---

    // Optional: Add a method to check if the episode is locked
    public function isLocked()
    {
        return $this->is_locked;
    }

    // Optional: Add a method to get the video URL
    public function getVideoUrlAttribute()
    {
        return $this->video ? asset('storage/' . $this->video) : null;
    }

    // Optional: Add a method to get the audio URL
    public function getAudioUrlAttribute()
    {
        return $this->audio ? asset('storage/' . $this->audio) : null;
    }
}