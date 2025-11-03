<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Log;

// --- Import your actual content models ---
 use App\Models\Course;
 use App\Models\Surah;
 use App\Models\Story;
 use App\Models\DeeperLook;  // <-- Added
 use App\Models\Commentary; // <-- Added

class ContentProgress extends Model
{
    use HasFactory;

    protected $table = 'content_progress';

    // Allow mass assignment for these fields
    protected $fillable = [
        'phone_number',
        'content_id',
        'content_type',
        'status',
        'progress_percentage',
        'last_accessed_at',
    ];

    // Automatically cast date/time fields
    protected $casts = [
        'last_accessed_at' => 'datetime',
    ];

    /**
     * Dynamically get the related content (Course, Surah, Story, DeeperLook, Commentary).
     * Note: Assumes corresponding models exist and are correctly namespaced.
     */
    public function content()
    {
        $modelClass = null;
        switch ($this->content_type) {
            case 'course':
                // Example using config (if you set it up) or hardcode
                // $modelClass = config('basirah.models.course', 'App\\Models\\Course');
                $modelClass = Course::class;
                break;
            case 'surah':
                $modelClass = Surah::class;
                break;
            case 'story':
                $modelClass = Story::class;
                break;
            case 'deeper_look': // <-- Added
                 $modelClass = DeeperLook::class;
                 break;
            case 'commentary': // <-- Added
                 $modelClass = Commentary::class;
                 break;
        }

        // Ensure the class exists before attempting to relate
        if ($modelClass && class_exists($modelClass)) {
            // Assumes the foreign key on the content_progress table is 'content_id'
            // and the primary key on the related tables (courses, surahs, etc.) is 'id'
            return $this->belongsTo($modelClass, 'content_id', 'id');
        }

        // Return null or handle cases where the model doesn't exist gracefully
        // This prevents errors if a content_type exists in the DB but the corresponding Model doesn't
        Log::warning("Model class not found or does not exist for content_type '{$this->content_type}'");
        return null;

        // Alternatively, you could return a MorphTo relationship if you were using Polymorphic relations,
        // but the current setup uses content_id and content_type strings.
        // return $this->morphTo(__FUNCTION__, 'content_type', 'content_id');
    }
}
