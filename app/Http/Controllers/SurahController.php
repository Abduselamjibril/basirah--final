<?php

namespace App\Http\Controllers;

use App\Models\Surah;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\SurahResource; // Import new resource

class SurahController extends Controller
{
        /**
         * @OA\Get(
         *     path="/surahs",
         *     summary="Get all surahs with episodes",
         *     tags={"Surah"},
         *     @OA\Response(response=200, description="List of surahs.")
         * )
         */
    public function index()
    {
        $surahs = Surah::with('episodes')->get();
        // Use the resource to transform the collection
        return SurahResource::collection($surahs);
    }

        /**
         * @OA\Get(
         *     path="/surahs/{id}",
         *     summary="Get a single surah by ID",
         *     tags={"Surah"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Surah ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Surah found."),
         *     @OA\Response(response=404, description="Surah not found.")
         * )
         */
    public function show($id)
    {
        $surah = Surah::with('episodes')->find($id);
        if (!$surah) {
            return response()->json(['error' => 'Surah not found.'], 404);
        }
        // Use the resource to transform the single model
        return new SurahResource($surah);
    }

        /**
         * @OA\Post(
         *     path="/surahs",
         *     summary="Create a new surah",
         *     tags={"Surah"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name"},
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Surah created successfully."),
         *     @OA\Response(response=422, description="Validation error.")
         * )
         */
    public function store(Request $request)
    {
        // Validation logic needs to be adapted for file uploads in API context
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'boolean',
        ]);

        $surah = new Surah();
        $surah->name = $validated['name'];
        $surah->description = $validated['description'] ?? null;
        $surah->is_premium = $validated['is_premium'] ?? false;

        if ($request->hasFile('image')) {
            $surah->image = $request->file('image')->store('surahs', 'public');
        }

        $surah->save();

        return response()->json([
            'message' => 'Surah created successfully.',
            'data' => new SurahResource($surah)
        ], 201);
    }

        /**
         * @OA\Put(
         *     path="/surahs/{id}",
         *     summary="Update a surah",
         *     tags={"Surah"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Surah ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=false,
         *         @OA\JsonContent(
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="image", type="string", format="binary"),
         *             @OA\Property(property="description", type="string"),
         *             @OA\Property(property="is_premium", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Surah updated successfully."),
         *     @OA\Response(response=404, description="Surah not found.")
         * )
         */
    public function update(Request $request, $id)
    {
        $surah = Surah::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $surah->fill($validated);

        if ($request->hasFile('image')) {
            if ($surah->image) {
                Storage::disk('public')->delete($surah->image);
            }
            $surah->image = $request->file('image')->store('surahs', 'public');
        }

        $surah->save();

        return response()->json([
            'message' => 'Surah updated successfully.',
            'data' => new SurahResource($surah)
        ], 200);
    }

        /**
         * @OA\Delete(
         *     path="/surahs/{id}",
         *     summary="Delete a surah",
         *     tags={"Surah"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Surah ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Surah deleted successfully."),
         *     @OA\Response(response=404, description="Surah not found.")
         * )
         */
    public function destroy($id)
    {
        $surah = Surah::findOrFail($id);
        // Episodes will be deleted by cascade constraint
        if ($surah->image) {
            Storage::disk('public')->delete($surah->image);
        }
        $surah->delete();
        return response()->json(['message' => 'Surah deleted successfully.'], 200);
    }

        /**
         * @OA\Patch(
         *     path="/surahs/{id}/lock",
         *     summary="Lock a surah and set it to premium",
         *     tags={"Surah"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Surah ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Surah locked and set to premium."),
         *     @OA\Response(response=404, description="Surah not found.")
         * )
         */
    public function lock($id)
    {
        $surah = Surah::findOrFail($id);
        $surah->is_premium = true;
        $surah->save();
        $surah->episodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Surah locked and set to premium.',
            'data' => new SurahResource($surah->load('episodes'))
        ]);
    }

        /**
         * @OA\Patch(
         *     path="/surahs/{id}/unlock",
         *     summary="Unlock a surah and set it to free",
         *     tags={"Surah"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Surah ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Surah unlocked and set to free."),
         *     @OA\Response(response=404, description="Surah not found.")
         * )
         */
    public function unlock($id)
    {
        $surah = Surah::findOrFail($id);
        $surah->is_premium = false;
        $surah->save();
        $surah->episodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Surah unlocked and set to free.',
            'data' => new SurahResource($surah->load('episodes'))
        ]);
    }
}
