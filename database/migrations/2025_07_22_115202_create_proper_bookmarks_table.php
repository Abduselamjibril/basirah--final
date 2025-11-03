<?php
// database/migrations/xxxx_xx_xx_xxxxxx_create_proper_bookmarks_table.php

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
        // We rename the old table to back it up. This is safer than dropping it immediately.
        if (Schema::hasTable('bookmarks') && !Schema::hasTable('bookmarks_old')) {
            Schema::rename('bookmarks', 'bookmarks_old');
        }

        // Create the new, properly structured table
        Schema::create('bookmarks', function (Blueprint $table) {
            $table->id();
            $table->string('phone_number')->index(); // The user identifier

            // These two columns are the magic of polymorphism!
            // They will store the ID and the Model Class of the item being bookmarked.
            $table->unsignedBigInteger('bookmarkable_id');
            $table->string('bookmarkable_type');

            $table->timestamps();

            // Add indexes for very fast lookups
            $table->index(['bookmarkable_id', 'bookmarkable_type']);

            // A user can only bookmark a specific item once. This ensures data integrity.
            $table->unique(['phone_number', 'bookmarkable_id', 'bookmarkable_type']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bookmarks');
        if (Schema::hasTable('bookmarks_old')) {
            Schema::rename('bookmarks_old', 'bookmarks');
        }
    }
};