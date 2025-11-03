<?php
// app/Models/Bookmark.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Bookmark extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'phone_number',
        'bookmarkable_id',
        'bookmarkable_type',
    ];

    /**
     * The attributes that should be cast to native types.
     * We no longer need any JSON casting.
     *
     * @var array
     */
    protected $casts = [];

    /**
     * Get the parent bookmarkable model (Course, Episode, etc.).
     * This is the core of the polymorphic relationship.
     */
    public function bookmarkable(): MorphTo
    {
        return $this->morphTo();
    }
}