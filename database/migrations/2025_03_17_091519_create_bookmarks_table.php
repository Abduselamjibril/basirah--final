<?php

// database/migrations/xxxx_xx_xx_xxxxxx_create_bookmarks_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateBookmarksTable extends Migration
{
    public function up()
    {
        Schema::create('bookmarks', function (Blueprint $table) {
            $table->id();
            $table->string('phone_number')->unique();
            $table->json('course_ids')->nullable();
            $table->json('episode_bookmarks')->nullable();
            $table->json('surah_ids')->nullable();
            $table->json('surah_episode_bookmarks')->nullable();
            $table->json('story_ids')->nullable();
            $table->json('story_episode_bookmarks')->nullable();
            // --- Added for full frontend support ---
            $table->json('commentary_ids')->nullable();
            $table->json('commentary_episode_bookmarks')->nullable();
            $table->json('deeper_look_ids')->nullable();
            $table->json('deeper_look_episode_bookmarks')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('bookmarks');
    }
}
