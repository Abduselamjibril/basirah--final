<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Playlist extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     * This is now much cleaner.
     */
    protected $fillable = [
        'user_id',
        'name',
    ];

    /**
     * The attributes that should be cast.
     * All JSON casts are removed.
     */
    protected $casts = [];

    /**
     * Get the user that owns the playlist.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get all of the items in the playlist, ordered correctly.
     */
    public function items(): HasMany
    {
        return $this->hasMany(PlaylistItem::class)->orderBy('order', 'asc');
    }
}