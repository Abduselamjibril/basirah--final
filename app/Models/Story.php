<?php

namespace App\Models;
use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Story extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = ['name', 'description', 'image', 'is_premium']; // Add is_premium

    // Define the relationship with StoryEpisode
    public function storyEpisodes()
    {
        return $this->hasMany(StoryEpisode::class);
    }
}
