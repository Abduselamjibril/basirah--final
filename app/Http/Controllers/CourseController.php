<?php

namespace App\Http\Controllers;

use App\Models\Course;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * @OA\Tag(
 *     name="Courses",
 *     description="API Endpoints for Courses"
 * )
 */
class CourseController extends Controller
{
    /**
     * The index method fetches courses with their episode counts.
     */
    /**
     * @OA\Get(
     *     path="/api/courses",
     *     tags={"Courses"},
     *     summary="Get all courses",
     *     @OA\Response(
     *         response=200,
     *         description="List of courses"
     *     )
     * )
     */
    public function index()
    {
        $courses = Course::withCount('episodes')->latest()->get();

        $transformedCourses = $courses->map(function ($course) {
            return [
                'id' => $course->id,
                'name' => $course->name,
                'description' => $course->description,
                'image_path' => $course->image_path ? Storage::disk('public')->url($course->image_path) : null,
                'is_premium' => (bool) $course->is_premium,
                'category' => $course->category,
                'episodes_count' => $course->episodes_count,
                'created_at' => $course->created_at->toDateTimeString(),
                'updated_at' => $course->updated_at->toDateTimeString(),
            ];
        });

        return response()->json(['data' => $transformedCourses]);
    }

    /**
     * The store method creates a new course.
     */
    /**
     * @OA\Post(
     *     path="/api/courses",
     *     tags={"Courses"},
     *     summary="Create a new course",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\MediaType(
     *             mediaType="multipart/form-data",
     *             @OA\Schema(
     *                 required={"name","description","image","category"},
     *                 @OA\Property(property="name", type="string"),
     *                 @OA\Property(property="description", type="string"),
     *                 @OA\Property(property="image", type="string", format="binary"),
     *                 @OA\Property(property="category", type="string")
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Course created successfully"
     *     )
     * )
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

        $transformedCourse = [
            'id' => $course->id,
            'name' => $course->name,
            'description' => $course->description,
            'image_path' => Storage::disk('public')->url($course->image_path),
            'is_premium' => (bool) $course->is_premium,
            'category' => $course->category,
            'episodes_count' => 0,
            'created_at' => $course->created_at->toDateTimeString(),
            'updated_at' => $course->updated_at->toDateTimeString(),
        ];

        return response()->json([
            'message' => 'Course created successfully.',
            'data' => $transformedCourse
        ], 201);
    }

    /**
     * The show method fetches a single course.
     */
    /**
     * @OA\Get(
     *     path="/api/courses/{id}",
     *     tags={"Courses"},
     *     summary="Get a single course",
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Course details"
     *     )
     * )
     */
    public function show($id)
    {
        $course = Course::withCount('episodes')->findOrFail($id);

        $transformedCourse = [
            'id' => $course->id,
            'name' => $course->name,
            'description' => $course->description,
            'image_path' => $course->image_path ? Storage::disk('public')->url($course->image_path) : null,
            'is_premium' => (bool) $course->is_premium,
            'category' => $course->category,
            'episodes_count' => $course->episodes_count,
            'created_at' => $course->created_at->toDateTimeString(),
            'updated_at' => $course->updated_at->toDateTimeString(),
        ];

        // --- FIX: Consistently wrap the response in a 'data' key ---
        return response()->json(['data' => $transformedCourse]);
    }

    /**
     * The update method updates an existing course.
     */
    /**
     * @OA\Put(
     *     path="/api/courses/{id}",
     *     tags={"Courses"},
     *     summary="Update a course",
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\MediaType(
     *             mediaType="multipart/form-data",
     *             @OA\Schema(
     *                 @OA\Property(property="name", type="string"),
     *                 @OA\Property(property="description", type="string"),
     *                 @OA\Property(property="image", type="string", format="binary"),
     *                 @OA\Property(property="category", type="string")
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Course updated successfully"
     *     )
     * )
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

        $transformedCourse = [
            'id' => $course->id,
            'name' => $course->name,
            'description' => $course->description,
            'image_path' => $course->image_path ? Storage::disk('public')->url($course->image_path) : null,
            'is_premium' => (bool) $course->is_premium,
            'category' => $course->category,
            'episodes_count' => $course->episodes_count,
            'created_at' => $course->created_at->toDateTimeString(),
            'updated_at' => $course->updated_at->toDateTimeString(),
        ];

        return response()->json([
            'message' => 'Course updated successfully.',
            'data' => $transformedCourse
        ], 200);
    }

    /**
     * @OA\Delete(
     *     path="/api/courses/{id}",
     *     tags={"Courses"},
     *     summary="Delete a course",
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Course deleted successfully"
     *     )
     * )
     */
    public function destroy($id)
    {
        $course = Course::findOrFail($id);
        if ($course->image_path) {
            Storage::disk('public')->delete($course->image_path);
        }
        $course->delete();
        return response()->json(['message' => 'Course deleted successfully.'], 200);
    }

    // --- FIX START: Return the updated course data from lock/unlock ---
    private function transformCourseForResponse(Course $course)
    {
        $course->loadCount('episodes');
        return [
            'id' => $course->id,
            'name' => $course->name,
            'description' => $course->description,
            'image_path' => $course->image_path ? Storage::disk('public')->url($course->image_path) : null,
            'is_premium' => (bool) $course->is_premium,
            'category' => $course->category,
            'episodes_count' => $course->episodes_count,
            'created_at' => $course->created_at->toDateTimeString(),
            'updated_at' => $course->updated_at->toDateTimeString(),
        ];
    }

    public function lock($id)
    {
        $course = Course::findOrFail($id);
        $course->is_premium = true;
        $course->save();
        $course->episodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Course locked and set to premium.',
            'data' => $this->transformCourseForResponse($course)
        ]);
    }

    public function unlock($id)
    {
        $course = Course::findOrFail($id);
        $course->is_premium = false;
        $course->save();
        $course->episodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Course unlocked and set to free.',
            'data' => $this->transformCourseForResponse($course)
        ]);
    }
    // --- FIX END ---
}
