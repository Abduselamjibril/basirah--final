<?php
// app/Http/Controllers/BookmarkController.php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Bookmark;
use Illuminate\Support\Facades\Response;
use Illuminate\Validation\Rule;

class BookmarkController extends Controller
{
    /**
     * A map to convert simple string types from the frontend
     * into the fully qualified model class names for our polymorphic relationship.
     */
    private const MODEL_MAP = [
        'course'                => \App\Models\Course::class,
        'surah'                 => \App\Models\Surah::class,
        'story'                 => \App\Models\Story::class,
        'commentary'            => \App\Models\Commentary::class,
        'deeper_look'           => \App\Models\DeeperLook::class,
        'episode'               => \App\Models\Episode::class,
        'surah_episode'         => \App\Models\SurahEpisode::class,
        'story_episode'         => \App\Models\StoryEpisode::class,
        'commentary_episode'    => \App\Models\CommentaryEpisode::class,
        'deeper_look_episode'   => \App\Models\DeeperLookEpisode::class,
    ];

    /**
     * Get all bookmarks for the authenticated user.
     * This single endpoint returns all bookmarked items with the content eager-loaded.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $bookmarks = Bookmark::where('phone_number', $user->phone_number)
            ->with(['bookmarkable' => function ($query) {
                // Eager load the related model (Course, Episode, etc.)
                // and add a 'laravel_model' attribute to the nested content,
                // which is very helpful for the frontend to know the type.
                $query->select('*')->selectSub(function ($sub) {
                    $sub->selectRaw('?', [$sub->from]);
                }, 'laravel_model');
            }])
            ->latest() // Order by most recently bookmarked
            ->get();

        return Response::json($bookmarks);
    }

    /**
     * Toggle a bookmark for any piece of content (parent or episode).
     */
    public function toggle(Request $request)
    {
        $validated = $request->validate([
            'type' => ['required', 'string', Rule::in(array_keys(self::MODEL_MAP))],
            'id' => 'required|integer|min:1',
        ]);

        $user = $request->user();
        $modelClass = self::MODEL_MAP[$validated['type']];

        // Check if the content actually exists
        if (!$modelClass::where('id', $validated['id'])->exists()) {
            return Response::json(['message' => 'The selected item could not be found.'], 404);
        }

        // Atomically find and delete or create the bookmark.
        $bookmark = Bookmark::where([
            'phone_number' => $user->phone_number,
            'bookmarkable_type' => $modelClass,
            'bookmarkable_id' => $validated['id'],
        ])->first();

        if ($bookmark) {
            $bookmark->delete();
            $message = 'Bookmark removed successfully';
        } else {
            Bookmark::create([
                'phone_number' => $user->phone_number,
                'bookmarkable_type' => $modelClass,
                'bookmarkable_id' => $validated['id'],
            ]);
            $message = 'Bookmark added successfully';
        }

        return Response::json(['message' => $message], 200);
    }
}