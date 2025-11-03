<?php

// database/migrations/xxxx_xx_xx_create_episodes_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('episodes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('course_id')->constrained()->onDelete('cascade');
            $table->string('title');
            $table->string('video_path')->nullable();
            $table->string('audio_path')->nullable();
            $table->string('youtube_link')->nullable();
            $table->boolean('is_locked')->default(false); // Add this line
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('episodes');
    }
};
