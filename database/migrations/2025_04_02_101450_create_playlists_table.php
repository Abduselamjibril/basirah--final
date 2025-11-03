<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreatePlaylistsTable extends Migration
{
    public function up()
    {
        Schema::create('playlists', function (Blueprint $table) {
            $table->id();
            $table->string('phone_number');
            $table->string('name');
            $table->json('course_episodes')->nullable();
            $table->json('surah_episodes')->nullable();
            $table->json('story_episodes')->nullable();
            // --- ADDED ---
            $table->json('commentary_episodes')->nullable();
            $table->json('deeper_look_episodes')->nullable();
            // --- END ADDED ---
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('playlists');
    }
}
