<?php

namespace App\Models;

// --- ADDED ---
use App\Models\Playlist;
use Illuminate\Database\Eloquent\Relations\MorphToMany;
// --- END ADDED ---

use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeeperLookEpisode extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'deeper_look_id',
        'name',
        'video',
        'audio',
        'youtube_link',
        'is_locked',
    ];

    public function deeperLook()
    {
        return $this->belongsTo(DeeperLook::class);
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

    public function isLocked()
    {
        return $this->is_locked;
    }

    public function getVideoUrlAttribute()
    {
        return $this->video ? asset('storage/' . $this->video) : null;
    }

    public function getAudioUrlAttribute()
    {
        return $this->audio ? asset('storage/' . $this->audio) : null;
    }
}