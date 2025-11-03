<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Check if table exists before creating
        if (!Schema::hasTable('episode_progress')) {
            Schema::create('episode_progress', function (Blueprint $table) {
                $table->id();
                $table->string('phone_number')->index(); // User identifier
                $table->unsignedBigInteger('episode_id')->index(); // ID of the episode being tracked
                $table->string('content_type')->index(); // 'course', 'surah', or 'story'
                $table->unsignedBigInteger('content_id')->index(); // ID of the parent course, surah, or story
                $table->unsignedInteger('watched_seconds')->default(0); // Max seconds watched
                $table->unsignedInteger('total_duration_seconds')->nullable(); // Optional: Total duration of the media
                $table->boolean('is_completed')->default(false); // Flag for episode completion
                $table->timestamps();

                // Unique constraint to prevent duplicate entries per user/episode
                $table->unique(['phone_number', 'episode_id']);

                // Add foreign key constraints if your episode tables exist and you want DB integrity
                // Example (adjust table/column names):
                // $table->foreign('episode_id')->references('id')->on('course_episodes')->onDelete('cascade');
                // $table->foreign('content_id')->references('id')->on('courses')->onDelete('cascade');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('episode_progress');
    }
};
