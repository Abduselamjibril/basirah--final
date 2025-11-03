<?php

namespace App\Models;
use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Commentary extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'title',
        'image',
        'description',
        'is_premium',
    ];

    public function episodes()
    {
        return $this->hasMany(CommentaryEpisode::class);
    }
}
