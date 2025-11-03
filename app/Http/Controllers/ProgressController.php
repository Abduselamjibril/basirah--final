<?php

namespace App\Http\Controllers;

use App\Models\ContentProgress;
use App\Models\EpisodeProgress;
use App\Models\Course;
use App\Models\Surah;
use App\Models\Story;
use App\Models\DeeperLook;
use App\Models\Commentary;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Carbon\Carbon;

class ProgressController extends Controller
{
    private const ALLOWED_CONTENT_TYPES = ['course', 'surah', 'story', 'deeper_look', 'commentary'];

    public function startTracking(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // 'phone_number' => 'required|string|regex:/^\+?[0-9\s\-()]+$/', // REMOVED
            'content_id'   => 'required|integer|min:1',
            'content_type' => ['required', 'string', Rule::in(self::ALLOWED_CONTENT_TYPES)],
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $validated = $validator->validated();
        $user = $request->user(); // ADDED

        try {
            $now = Carbon::now();
            $contentProgress = ContentProgress::updateOrCreate(
                [
                    'phone_number' => $user->phone_number, // CHANGED
                    'content_id'   => $validated['content_id'],
                    'content_type' => $validated['content_type'],
                ],
                [
                    'last_accessed_at' => $now,
                ]
            );

            if ($contentProgress->wasRecentlyCreated || $contentProgress->status === 'not_started') {
                $contentProgress->status = 'in_progress';
                 if ($contentProgress->wasRecentlyCreated) {
                     $contentProgress->progress_percentage = 0;
                 }
                $contentProgress->save();
            }

            return response()->json([
                'message' => 'Tracking started/updated successfully.',
                'status' => $contentProgress->status
            ], 200);

        } catch (\Exception $e) {
            Log::error('Error in startTracking: ' . $e->getMessage());
            return response()->json(['message' => 'Server error occurred while starting tracking.'], 500);
        }
    }

    public function updateProgress(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // 'phone_number'           => 'required|string|regex:/^\+?[0-9\s\-()]+$/', // REMOVED
            'episode_id'             => 'required|integer|min:1',
            'content_id'             => 'required|integer|min:1',
            'content_type'           => ['required', 'string', Rule::in(self::ALLOWED_CONTENT_TYPES)],
            'current_position_seconds' => 'required|integer|min:0',
            'total_duration_seconds' => 'sometimes|integer|min:0',
            'is_completed'           => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $validated = $validator->validated();
        $user = $request->user(); // ADDED

        try {
            DB::beginTransaction();

            $episodeProgress = EpisodeProgress::firstOrNew(
                [
                    'phone_number' => $user->phone_number, // CHANGED
                    'episode_id'   => $validated['episode_id'],
                ]
            );

            $episodeProgress->content_type = $validated['content_type'];
            $episodeProgress->content_id = $validated['content_id'];

            if ($validated['current_position_seconds'] > $episodeProgress->watched_seconds) {
                $episodeProgress->watched_seconds = $validated['current_position_seconds'];
            }

            if (isset($validated['total_duration_seconds'])) {
                $episodeProgress->total_duration_seconds = $validated['total_duration_seconds'];
            }

            $completed = $episodeProgress->is_completed;
            if (array_key_exists('is_completed', $validated)) {
                 $completed = $validated['is_completed'];
            }
            $episodeProgress->is_completed = $completed;

            $episodeProgress->save();

            $this->_recalculateContentProgress(
                $user->phone_number, // CHANGED
                $validated['content_id'],
                $validated['content_type']
            );

            DB::commit();

            return response()->json(['message' => 'Progress updated successfully.'], 200);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error in updateProgress: ' . $e->getMessage());
            return response()->json(['message' => 'Server error occurred while updating progress.'], 500);
        }
    }

    public function getMyLearning(Request $request)
    {
        // Validator no longer needed as we get the user directly
        $user = $request->user(); // ADDED
        $phoneNumber = $user->phone_number; // CHANGED

        try {
            $progressRecords = ContentProgress::where('phone_number', $phoneNumber)
                ->whereIn('status', ['in_progress', 'completed'])
                ->orderBy('last_accessed_at', 'desc')
                ->get();

            $inProgressContent = [];
            $completedContent = [];

            foreach ($progressRecords as $record) {
                $tableName = '';
                $nameField = 'name';
                $imageField = 'image';

                switch ($record->content_type) {
                    case 'course':
                        $tableName = 'courses';
                        $imageField = 'image_path';
                        break;
                    case 'surah':
                        $tableName = 'surahs';
                        break;
                    case 'story':
                        $tableName = 'stories';
                        break;
                    case 'deeper_look':
                        $tableName = 'deeper_looks';
                        break;
                    case 'commentary':
                        $tableName = 'commentaries';
                        $nameField = 'title';
                        break;
                    default:
                        Log::warning("Unknown content type '{$record->content_type}' encountered in getMyLearning for user {$phoneNumber}.");
                        continue 2;
                }

                $contentDetails = null;
                if (Schema::hasTable($tableName)) {
                    $contentDetails = DB::table($tableName)
                                        ->where('id', $record->content_id)
                                        ->select('id', "$nameField as name", "$imageField as image")
                                        ->first();
                } else {
                    Log::warning("Table '{$tableName}' not found for content type '{$record->content_type}'.");
                    continue;
                }

                if ($contentDetails) {
                    $detailsArray = json_decode(json_encode($contentDetails), true);
                    $formattedRecord = [
                        'content_id'           => $record->content_id,
                        'content_type'         => $record->content_type,
                        'status'               => $record->status,
                        'progress_percentage'  => $record->progress_percentage,
                        'last_accessed_at'     => $record->last_accessed_at ? $record->last_accessed_at->toIso8601String() : null,
                        'name'                 => $detailsArray['name'] ?? 'N/A',
                        'image'                => $detailsArray['image'] ?? null,
                    ];

                    if ($formattedRecord['image']) {
                        $imagePath = ltrim($formattedRecord['image'], '/');
                        if (strpos($imagePath, 'storage/') === 0) {
                            $formattedRecord['image_url'] = asset($imagePath);
                        } else {
                            $formattedRecord['image_url'] = asset('storage/' . $imagePath);
                        }
                    } else {
                        $formattedRecord['image_url'] = null;
                    }

                    if ($record->status === 'in_progress') {
                        $inProgressContent[] = $formattedRecord;
                    } else {
                        $completedContent[] = $formattedRecord;
                    }
                } else {
                    Log::warning("Content details not found in table '{$tableName}' for {$record->content_type} ID {$record->content_id}.");
                }
            }

            return response()->json([
                'in_progress' => $inProgressContent,
                'completed'   => $completedContent,
            ]);

        } catch (\Exception $e) {
            Log::error('Error in getMyLearning: ' . $e->getMessage() . ' Trace: ' . $e->getTraceAsString());
            return response()->json(['message' => 'Server error occurred while fetching learning progress.'], 500);
        }
    }

    private function _recalculateContentProgress(string $phoneNumber, int $contentId, string $contentType)
    {
        try {
            $episodeTableName = '';
            $foreignKey = '';

            switch ($contentType) {
                case 'course':
                    $episodeTableName = 'episodes'; // Match your actual table name if different
                    $foreignKey = 'course_id';
                    break;
                case 'surah':
                    $episodeTableName = 'surah_episodes';
                    $foreignKey = 'surah_id';
                    break;
                case 'story':
                    $episodeTableName = 'story_episodes';
                    $foreignKey = 'story_id';
                    break;
                case 'deeper_look':
                    $episodeTableName = 'deeper_look_episodes';
                    $foreignKey = 'deeper_look_id';
                    break;
                case 'commentary':
                    $episodeTableName = 'commentary_episodes';
                    $foreignKey = 'commentary_id';
                    break;
                default:
                    Log::warning("Unknown content type '{$contentType}' provided for recalculation.");
                    return;
            }

            if (!Schema::hasTable($episodeTableName) || !Schema::hasColumn($episodeTableName, $foreignKey)) {
                Log::error("Episode table '{$episodeTableName}' or FK '{$foreignKey}' not found for recalculating progress.");
                return;
            }

            $contentProgress = ContentProgress::firstOrCreate(
                ['phone_number' => $phoneNumber, 'content_id' => $contentId, 'content_type' => $contentType],
                ['status' => 'not_started', 'progress_percentage' => 0, 'last_accessed_at' => Carbon::now()]
            );

             $totalEpisodes = DB::table($episodeTableName)->where($foreignKey, $contentId)->count();

            if ($totalEpisodes === 0) {
                $contentProgress->progress_percentage = 0;
                if ($contentProgress->status === 'not_started') {
                    $contentProgress->status = 'in_progress';
                }
                $contentProgress->save();
                return;
            }

            $completedEpisodes = EpisodeProgress::where('phone_number', $phoneNumber)
                ->where('content_id', $contentId)
                ->where('content_type', $contentType)
                ->where('is_completed', true)
                 ->whereIn('episode_id', function($query) use ($episodeTableName, $foreignKey, $contentId) {
                     $query->select('id')->from($episodeTableName)->where($foreignKey, $contentId);
                 })
                ->count();

            $percentage = round(($completedEpisodes / $totalEpisodes) * 100);
            $percentage = min($percentage, 100);

            $status = 'in_progress';
            if ($percentage >= 100) {
                $status = 'completed';
            } elseif ($percentage > 0) {
                $status = 'in_progress';
            } else {
                $status = ($contentProgress->status === 'not_started') ? 'in_progress' : $contentProgress->status;
            }

            $contentProgress->progress_percentage = $percentage;
            $contentProgress->status = $status;
            $contentProgress->save();

        } catch (\Exception $e) {
            Log::error("Error recalculating progress for {$contentType} ID {$contentId}, user {$phoneNumber}: " . $e->getMessage());
        }
    }
}
