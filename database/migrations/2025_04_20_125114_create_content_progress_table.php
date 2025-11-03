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
        if (!Schema::hasTable('content_progress')) {
            Schema::create('content_progress', function (Blueprint $table) {
                $table->id();
                $table->string('phone_number')->index(); // User identifier
                $table->unsignedBigInteger('content_id'); // ID of the course, surah, or story
                $table->string('content_type'); // 'course', 'surah', or 'story'
                $table->enum('status', ['not_started', 'in_progress', 'completed'])->default('not_started');
                $table->unsignedTinyInteger('progress_percentage')->default(0); // Overall progress %
                $table->timestamp('last_accessed_at')->nullable(); // When user last interacted
                $table->timestamps();

                // Unique constraint for user+content combination
                $table->unique(['phone_number', 'content_id', 'content_type'], 'user_content_unique');

                // Index for faster querying by status
                 $table->index(['phone_number', 'status']);
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('content_progress');
    }
};
