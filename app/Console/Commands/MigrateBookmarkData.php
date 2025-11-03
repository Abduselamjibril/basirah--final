<?php
// app/Console/Commands/MigrateBookmarkData.php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Models\Course;
use App\Models\Surah;
use App\Models\Story;
use App\Models\Commentary;
use App\Models\DeeperLook;
use App\Models\Episode;
use App\Models\SurahEpisode;
use App\Models\StoryEpisode;
use App\Models\CommentaryEpisode;
use App\Models\DeeperLookEpisode;

class MigrateBookmarkData extends Command
{
    protected $signature = 'data:migrate-bookmarks';

    protected $description = 'Migrates bookmark data from the old JSON structure to the new polymorphic table.';

    public function handle(): int
    {
        $this->info('Starting bookmark data migration...');

        // Step 1: Run the migration to rename the old table and create the new one.
        // Find the new migration file you created in `database/migrations` and put its exact name here.
        $migrationFileName = '2025_07_22_115202_create_proper_bookmarks_table.php'; // <--- IMPORTANT: UPDATE THIS FILENAME
        
        try {
            $this->call('migrate', [
                '--path' => 'database/migrations/' . $migrationFileName,
                '--force' => true,
            ]);
            $this->info('New `bookmarks` table created and old table renamed to `bookmarks_old`.');
        } catch (\Exception $e) {
            $this->error("Migration failed. Please ensure the filename '{$migrationFileName}' is correct and the migration hasn't run yet.");
            $this->error($e->getMessage());
            return self::FAILURE;
        }

        // Step 2: Migrate the data within a database transaction for safety.
        DB::transaction(function () {
            if (!Schema::hasTable('bookmarks_old')) {
                $this->warn('Old bookmarks table (`bookmarks_old`) not found. Skipping data migration.');
                return;
            }

            $oldBookmarks = DB::table('bookmarks_old')->get();
            $newBookmarks = [];

            if ($oldBookmarks->isEmpty()) {
                $this->info("The old `bookmarks_old` table is empty. No data to migrate.");
                return;
            }
            
            $this->info("Found " . $oldBookmarks->count() . " records in the old bookmarks table to process.");
            $progressBar = $this->output->createProgressBar($oldBookmarks->count());

            foreach ($oldBookmarks as $oldBookmark) {
                $phoneNumber = $oldBookmark->phone_number;

                // --- Process all the JSON columns ---
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->course_ids, Course::class);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->surah_ids, Surah::class);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->story_ids, Story::class);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->commentary_ids, Commentary::class);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->deeper_look_ids, DeeperLook::class);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->episode_bookmarks, Episode::class, true);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->surah_episode_bookmarks, SurahEpisode::class, true);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->story_episode_bookmarks, StoryEpisode::class, true);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->commentary_episode_bookmarks, CommentaryEpisode::class, true);
                $this->processJsonColumn($newBookmarks, $phoneNumber, $oldBookmark->deeper_look_episode_bookmarks, DeeperLookEpisode::class, true);
                
                $progressBar->advance();
            }
            
            $progressBar->finish();
            $this->newLine();

            // Insert all new bookmarks in a single, efficient query
            if (!empty($newBookmarks)) {
                // To avoid unique constraint errors on re-runs, we can use insertOrIgnore or chunking.
                // For a one-time script, chunking and inserting is robust.
                $chunks = array_chunk($newBookmarks, 500);
                foreach ($chunks as $chunk) {
                    DB::table('bookmarks')->insertOrIgnore($chunk);
                }
                $this->info("Processed " . count($newBookmarks) . " potential new bookmark records.");
            } else {
                $this->info("No valid bookmark records found to insert.");
            }
        });

        $this->info('Bookmark data migration completed successfully!');
        $this->warn('Review the new `bookmarks` table. Once confirmed, you can create a new migration to `Schema::dropIfExists(\'bookmarks_old\')`.');

        return self::SUCCESS;
    }

    private function processJsonColumn(array &$newBookmarks, string $phoneNumber, ?string $jsonColumnData, string $modelClass, bool $isNested = false): void
    {
        if (empty($jsonColumnData)) return;
        $items = json_decode($jsonColumnData, true);
        if (!is_array($items) || empty($items)) return;

        $idsToInsert = $isNested ? array_merge(...array_values($items)) : $items;
        
        foreach ($idsToInsert as $id) {
            if (!is_numeric($id) || intval($id) <= 0) continue;
            $newBookmarks[] = [
                'phone_number' => $phoneNumber,
                'bookmarkable_id' => intval($id),
                'bookmarkable_type' => $modelClass,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }
    }
}