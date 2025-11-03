<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EpisodeProgress extends Model
{
    use HasFactory;

    protected $table = 'episode_progress';

    // Allow mass assignment for these fields
    protected $fillable = [
        'phone_number',
        'episode_id',
        'content_type',
        'content_id',
        'watched_seconds',
        'total_duration_seconds',
        'is_completed',
    ];

    // Automatically cast boolean fields
    protected $casts = [
        'is_completed' => 'boolean',
    ];
}
