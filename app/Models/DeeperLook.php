<?php

namespace App\Models;
use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage; // Import Storage

class DeeperLook extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = [
        'name',
        'image',
        'description',
        'is_premium',
    ];

    /**
     * The "booted" method of the model.
     *
     * @return void
     */
    protected static function booted()
    {
        static::deleting(function ($deeperLook) {
            // Delete associated episodes before deleting the deeper look itself
            $deeperLook->episodes()->each(function ($episode) {
                // This assumes the DeeperLookEpisode model has its own deleting event
                // to handle file cleanup. If not, you'd add that logic here.
                $episode->delete();
            });

            // Delete the main image for the DeeperLook
            if ($deeperLook->image) {
                Storage::disk('public')->delete($deeperLook->image);
            }
        });
    }

    public function episodes()
    {
        return $this->hasMany(DeeperLookEpisode::class);
    }
}
