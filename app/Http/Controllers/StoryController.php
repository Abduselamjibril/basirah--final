<?php

namespace App\Http\Controllers;

use App\Models\Story;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Cache;
use App\Http\Resources\StoryResource; // Import new resource

class StoryController extends Controller
{
    public function index()
    {
        // FIXED: Eager load relationships AND count to prevent N+1 queries.
        // `withCount` adds a `story_episodes_count` attribute to each story.
        $stories = Cache::remember('stories_all', 3600, function () {
            return Story::with('storyEpisodes')->withCount('storyEpisodes')->get();
        });
        return StoryResource::collection($stories);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'image' => 'image|nullable|max:1999',
            'is_premium' => 'sometimes|boolean',
        ]);

        $story = new Story($validated);

        if ($request->hasFile('image')) {
            $story->image = $request->file('image')->store('images', 'public');
        }

        $story->save();

        Cache::forget('stories_all');

        return response()->json([
            'message' => 'Story created successfully.',
            'data' => new StoryResource($story)
        ], 201);
    }

    public function show(Story $story)
    {
        // Eager load the relationship
        $story->load('storyEpisodes');
        return new StoryResource($story);
    }

    public function update(Request $request, Story $story)
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'sometimes|required|string',
            'image' => 'image|nullable|max:1999',
            'is_premium' => 'sometimes|boolean',
        ]);

        $story->fill($validated);

        if ($request->hasFile('image')) {
            if ($story->image) {
                Storage::disk('public')->delete($story->image);
            }
            $story->image = $request->file('image')->store('images', 'public');
        }

        $story->save();

        Cache::forget('stories_all');

        return response()->json([
            'message' => 'Story updated successfully.',
            'data' => new StoryResource($story)
        ], 200);
    }

    public function destroy(Story $story)
    {
        if ($story->image) {
            Storage::disk('public')->delete($story->image);
        }
        $story->delete();
        
        Cache::forget('stories_all');
        
        return response()->json(['message' => 'Story deleted successfully'], 200);
    }

    // FIXED: Using Route-Model binding for cleaner code
    public function lock(Story $story)
    {
        $story->is_premium = true;
        $story->save();
        $story->storyEpisodes()->update(['is_locked' => true]);

        Cache::forget('stories_all');

        return response()->json([
            'message' => 'Story locked and set to premium.',
            'data' => new StoryResource($story->load('storyEpisodes'))
        ]);
    }

    // FIXED: Using Route-Model binding for cleaner code
    public function unlock(Story $story)
    {
        $story->is_premium = false;
        $story->save();
        $story->storyEpisodes()->update(['is_locked' => false]);

        Cache::forget('stories_all');

        return response()->json([
            'message' => 'Story unlocked and set to free.',
            'data' => new StoryResource($story->load('storyEpisodes'))
        ]);
    }
}
