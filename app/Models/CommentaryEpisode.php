<?php

namespace App\Models;

// --- ADDED ---
use App\Models\Playlist; // Required for the new relationship
use Illuminate\Database\Eloquent\Relations\MorphToMany;
// --- END ADDED ---

use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CommentaryEpisode extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'commentary_id',
        'title',
        'video',
        'audio',
        'youtube_link',
        'is_locked',
    ];

    public function commentary()
    {
        return $this->belongsTo(Commentary::class);
    }

    // --- ADDED: The Polymorphic Relationship ---
    /**
     * Get all of the playlists that this episode is a part of.
     *
     * This is the core of the new system. It allows a CommentaryEpisode
     * to belong to many playlists through the 'playlist_items' table.
     * The 'playlistable' string is the name we used in the migration.
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