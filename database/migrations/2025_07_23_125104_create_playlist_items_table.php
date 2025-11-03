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
        Schema::create('playlist_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('playlist_id')->constrained()->onDelete('cascade');
            
            // The polymorphic columns
            $table->morphs('playlistable'); // This creates `playlistable_id` and `playlistable_type`

            $table->unsignedInteger('order')->default(0)->comment('The order of the item within the playlist');
            $table->timestamps();

            // Unique constraint to prevent adding the same episode to the same playlist twice
            $table->unique(['playlist_id', 'playlistable_id', 'playlistable_type'], 'playlist_item_unique');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('playlist_items');
    }
};