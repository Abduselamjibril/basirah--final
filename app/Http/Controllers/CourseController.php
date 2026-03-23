<?php

namespace App\Http\Controllers;

use App\Models\Course;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Cache;
use App\Http\Traits\ChecksContentAccess;
use App\Http\Resources\CourseResource;

class CourseController extends Controller
{
    use ChecksContentAccess;

    /**
     * The index method fetches courses with their episode counts.
     */
    public function index()
    {
        $courses = Cache::remember('courses_all', 3600, function () {
            return Course::withCount('episodes')->latest()->get();
        });
        return CourseResource::collection($courses);
    }

    /**
     * The store method creates a new course.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'image' => 'required|image|mimes:jpeg,png,jpg,gif,svg,png|max:10240',
            'category' => 'required|string|in:Introduction to Quran,Messages in Quran',
        ]);

        $imagePath = $request->file('image')->store('courses', 'public');
        $course = Course::create([
            'name' => $request->name,
            'description' => $request->description,
            'image_path' => $imagePath,
            'is_premium' => false,
            'category' => $request->category,
        ]);

        // Load episodes count to match resource expectation
        $course->setAttribute('episodes_count', 0);

        Cache::forget('courses_all');

        return response()->json([
            'message' => 'Course created successfully.',
            'data' => new CourseResource($course)
        ], 201);
    }

    /**
     * The show method fetches a single course.
     */
    public function show($id)
    {
        $course = Course::withCount('episodes')->findOrFail($id);
        return new CourseResource($course);
    }

    /**
     * The update method updates an existing course.
     */
    public function update(Request $request, $id)
    {
        $course = Course::findOrFail($id);

        $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'sometimes|required|string',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,svg,png|max:10240',
            'category' => 'sometimes|required|string|in:Introduction to Quran,Messages in Quran',
        ]);
        
        $courseData = $request->only(['name', 'description', 'category']);
        
        if ($request->hasFile('image')) {
            if ($course->image_path) {
                Storage::disk('public')->delete($course->image_path);
            }
            $courseData['image_path'] = $request->file('image')->store('courses', 'public');
        }

        $course->update($courseData);
        $course->loadCount('episodes');

        Cache::forget('courses_all');

        return response()->json([
            'message' => 'Course updated successfully.',
            'data' => new CourseResource($course)
        ], 200);
    }

    public function destroy($id)
    {
        $course = Course::findOrFail($id);
        if ($course->image_path) {
            Storage::disk('public')->delete($course->image_path);
        }
        $course->delete();
        
        Cache::forget('courses_all');
        
        return response()->json(['message' => 'Course deleted successfully.'], 200);
    }

    public function lock($id)
    {
        $course = Course::findOrFail($id);
        $course->is_premium = true;
        $course->save();
        $course->episodes()->update(['is_locked' => true]);
        
        $course->loadCount('episodes');

        Cache::forget('courses_all');

        return response()->json([
            'message' => 'Course locked and set to premium.',
            'data' => new CourseResource($course)
        ]);
    }

    public function unlock($id)
    {
        $course = Course::findOrFail($id);
        $course->is_premium = false;
        $course->save();
        $course->episodes()->update(['is_locked' => false]);
        
        $course->loadCount('episodes');

        Cache::forget('courses_all');

        return response()->json([
            'message' => 'Course unlocked and set to free.',
            'data' => new CourseResource($course)
        ]);
    }
}