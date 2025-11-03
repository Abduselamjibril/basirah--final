<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateStoryEpisodesTable extends Migration
{
    public function up()
    {
        Schema::create('story_episodes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('story_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->string('video')->nullable();
            $table->string('audio')->nullable();
            $table->string('youtube_link')->nullable(); // Added youtube_link column
            $table->boolean('is_locked')->default(false); // Added is_locked column
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('story_episodes');
    }
}
