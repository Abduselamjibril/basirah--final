<?php

namespace App\Console\Commands;

use App\Models\Playlist;
use App\Models\PlaylistItem;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class MigrateOldPlaylistsData extends Command
{
    protected $signature = 'data:migrate-playlists';
    protected $description = 'Migrates data from the old JSON-based playlists table to the new relational structure.';

    private const MODEL_MAP = [
        'course_episodes' => \App\Models\Episode::class,
        'surah_episodes' => \App\Models\SurahEpisode::class,
        'story_episodes' => \App\Models\StoryEpisode::class,
        'commentary_episodes' => \App\Models\CommentaryEpisode::class,
        'deeper_look_episodes' => \App\Models\DeeperLookEpisode::class,
    ];

    public function handle(): int
    {
        $this->info('Starting playlist data migration...');

        // Use a cursor to handle large tables without memory issues
        $oldPlaylists = DB::table('playlists_old')->cursor();
        $progressBar = $this->output->createProgressBar($oldPlaylists->count());

        foreach ($oldPlaylists as $oldPlaylist) {
            // Using a try-catch inside the loop makes the process more resilient.
            // One bad record won't halt the entire migration.
            try {
                DB::transaction(function () use ($oldPlaylist) {
                    // Robustness: Skip if phone number is missing in the old data
                    if (empty($oldPlaylist->phone_number)) {
                        $this->warn("Skipping old playlist ID {$oldPlaylist->id} due to missing phone number.");
                        return; // continue to the next playlist
                    }

                    $user = User::where('phone_number', $oldPlaylist->phone_number)->first();

                    if (!$user) {
                        $this->warn("Skipping old playlist ID {$oldPlaylist->id}: User with phone {$oldPlaylist->phone_number} not found.");
                        return; // continue to the next playlist
                    }

                    // 1. Create the new playlist entry
                    $newPlaylist = Playlist::create([
                        'user_id' => $user->id,
                        'name' => $oldPlaylist->name,
                        'created_at' => $oldPlaylist->created_at,
                        'updated_at' => $oldPlaylist->updated_at,
                    ]);

                    $order = 1;

                    // 2. Iterate and create playlist items
                    foreach (self::MODEL_MAP as $jsonColumn => $modelClass) {
                        if (empty($oldPlaylist->{$jsonColumn})) continue;
                        
                        $episodeIds = json_decode($oldPlaylist->{$jsonColumn}, true);
                        if (!is_array($episodeIds)) continue;

                        foreach ($episodeIds as $episodeId) {
                            if (DB::table((new $modelClass)->getTable())->where('id', $episodeId)->exists()) {
                                PlaylistItem::create([
                                    'playlist_id' => $newPlaylist->id,
                                    'playlistable_id' => $episodeId,
                                    'playlistable_type' => $modelClass,
                                    'order' => $order++,
                                ]);
                            } else {
                                $this->warn(" [Playlist:{$newPlaylist->name}] Dangling reference skipped: Model {$modelClass}, ID {$episodeId}");
                            }
                        }
                    }
                });
            } catch (Throwable $e) {
                // Log the error with context
                Log::error("Failed to migrate playlist with old ID: {$oldPlaylist->id}. Error: " . $e->getMessage());
                $this->error(" Failed to process old playlist ID: {$oldPlaylist->id}. See laravel.log for details.");
            }

            // Advance the progress bar for every record, whether skipped or processed.
            $progressBar->advance();
        }

        $progressBar->finish();
        $this->info("\nPlaylist data migration completed!");
        return Command::SUCCESS;
    }
}