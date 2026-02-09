<?php

namespace App\Http\Controllers;

use App\Models\AboutUs;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AboutUsController extends Controller
{
    // Public method for Flutter App
        /**
         * @OA\Get(
         *     path="/about-us",
         *     summary="Get About Us content",
         *     tags={"AboutUs"},
         *     @OA\Response(response=200, description="About Us content returned")
         * )
         */
    public function get()
    {
        $content = AboutUs::firstOrCreate(
            ['id' => 1],
            ['title' => 'About Us', 'content' => 'Welcome! Content is being updated.']
        );
        return response()->json($content);
    }

    // Admin method to update content
        /**
         * @OA\Post(
         *     path="/admin/about-us",
         *     summary="Update About Us content",
         *     tags={"AboutUs"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"title","content"},
         *             @OA\Property(property="title", type="string"),
         *             @OA\Property(property="content", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="About Us updated"),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */
    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'content' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $content = AboutUs::updateOrCreate(
            ['id' => 1],
            $request->only(['title', 'content'])
        );

        return response()->json(['message' => 'About Us page updated successfully.', 'data' => $content]);
    }
}
