<?php

namespace App\Http\Controllers;

use App\Models\DeeperLook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\DeeperLookResource; // Import new resource

class DeeperLookController extends Controller
{
    public function index()
    {
        $deeperLooks = DeeperLook::with('episodes')->get();
        return DeeperLookResource::collection($deeperLooks);
    }
        /**
         * @OA\Get(
         *     path="/deeper-looks",
         *     summary="Get all deeper looks",
         *     tags={"DeeperLook"},
         *     @OA\Response(response=200, description="List of deeper looks")
         * )
         */

    public function show($id)
    {
        $deeperLook = DeeperLook::with('episodes')->find($id);
        if (!$deeperLook) {
            return response()->json(['error' => 'Deeper Look not found.'], 404);
        }
        return new DeeperLookResource($deeperLook);
    }
        /**
         * @OA\Get(
         *     path="/deeper-looks/{id}",
         *     summary="Get a single deeper look by ID",
         *     tags={"DeeperLook"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Deeper Look ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Deeper Look found"),
         *     @OA\Response(response=404, description="Deeper Look not found.")
         * )
         */

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $deeperLook = new DeeperLook($validated);

        if ($request->hasFile('image')) {
            $deeperLook->image = $request->file('image')->store('deeperlooks', 'public');
        }

        $deeperLook->save();

        return response()->json([
            'message' => 'Deeper Look created successfully.',
            'data' => new DeeperLookResource($deeperLook)
        ], 201);
    }
        /**
         * @OA\Post(
         *     path="/deeper-looks",
         *     summary="Create a new deeper look",
         *     tags={"DeeperLook"},
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
         *     @OA\Response(response=201, description="Deeper Look created successfully."),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */

    public function update(Request $request, $id)
    {
        $deeperLook = DeeperLook::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'image' => 'image|nullable|max:2048',
            'description' => 'nullable|string',
            'is_premium' => 'sometimes|boolean',
        ]);

        $deeperLook->fill($validated);

        if ($request->hasFile('image')) {
            if ($deeperLook->image) {
                Storage::disk('public')->delete($deeperLook->image);
            }
            $deeperLook->image = $request->file('image')->store('deeperlooks', 'public');
        }

        $deeperLook->save();

        return response()->json([
            'message' => 'Deeper Look updated successfully.',
            'data' => new DeeperLookResource($deeperLook)
        ], 200);
    }
        /**
         * @OA\Put(
         *     path="/deeper-looks/{id}",
         *     summary="Update a deeper look",
         *     tags={"DeeperLook"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Deeper Look ID",
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
         *     @OA\Response(response=200, description="Deeper Look updated successfully."),
         *     @OA\Response(response=404, description="Deeper Look not found.")
         * )
         */

    public function destroy($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        if ($deeperLook->image) {
            Storage::disk('public')->delete($deeperLook->image);
        }
        $deeperLook->delete();
        return response()->json(['message' => 'Deeper Look deleted successfully.'], 200);
    }
        /**
         * @OA\Delete(
         *     path="/deeper-looks/{id}",
         *     summary="Delete a deeper look",
         *     tags={"DeeperLook"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Deeper Look ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Deeper Look deleted successfully."),
         *     @OA\Response(response=404, description="Deeper Look not found.")
         * )
         */

    public function lock($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        $deeperLook->is_premium = true;
        $deeperLook->save();
        $deeperLook->episodes()->update(['is_locked' => true]);

        return response()->json([
            'message' => 'Deeper Look locked and set to premium.',
            'data' => new DeeperLookResource($deeperLook->load('episodes'))
        ]);
    }
        /**
         * @OA\Patch(
         *     path="/deeper-looks/{id}/lock",
         *     summary="Lock a deeper look and set to premium",
         *     tags={"DeeperLook"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Deeper Look ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Deeper Look locked and set to premium."),
         *     @OA\Response(response=404, description="Deeper Look not found.")
         * )
         */

    public function unlock($id)
    {
        $deeperLook = DeeperLook::findOrFail($id);
        $deeperLook->is_premium = false;
        $deeperLook->save();
        $deeperLook->episodes()->update(['is_locked' => false]);

        return response()->json([
            'message' => 'Deeper Look unlocked and set to free.',
            'data' => new DeeperLookResource($deeperLook->load('episodes'))
        ]);
    }
        /**
         * @OA\Patch(
         *     path="/deeper-looks/{id}/unlock",
         *     summary="Unlock a deeper look and set to free",
         *     tags={"DeeperLook"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="Deeper Look ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Deeper Look unlocked and set to free."),
         *     @OA\Response(response=404, description="Deeper Look not found.")
         * )
         */
}
