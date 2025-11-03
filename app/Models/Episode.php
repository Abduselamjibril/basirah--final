<?php

namespace App\Models;

// --- ADDED ---
use App\Models\Playlist;
use Illuminate\Database\Eloquent\Relations\MorphToMany;
// --- END ADDED ---

use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Episode extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'course_id',
        'title',
        'video_path',
        'audio_path',
        'youtube_link',
        'is_locked', // Include is_locked
    ];

    public function course()
    {
        return $this->belongsTo(Course::class);
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

    // Optional: Method to check if the episode is locked
    public function isLocked()
    {
        return $this->is_locked;
    }

    // Optional: Method to get the video URL
    public function getVideoUrlAttribute()
    {
        return $this->video_path ? asset('storage/' . $this->video_path) : null;
    }

    // Optional: Method to get the audio URL
    public function getAudioUrlAttribute()
    {
        return $this->audio_path ? asset('storage/' . $this->audio_path) : null;
    }
}