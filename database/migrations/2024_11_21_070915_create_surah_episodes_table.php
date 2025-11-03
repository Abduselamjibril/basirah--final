<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('surah_episodes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('surah_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->string('video')->nullable();
            $table->string('audio')->nullable();
            $table->string('youtube_link')->nullable();
            $table->boolean('is_locked')->default(false); // Added this line
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('surah_episodes');
    }
};
