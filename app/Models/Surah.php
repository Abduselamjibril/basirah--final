<?php

namespace App\Models;
use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Surah extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'name',
        'image',
        'description',
        'is_premium',
    ];

    public function episodes()
    {
        return $this->hasMany(SurahEpisode::class);
    }
}
