<?php

namespace App\Http\Controllers;

use App\Models\PrivacyPolicy;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class PrivacyPolicyController extends Controller
{
    // Public method for Flutter App
        /**
         * @OA\Get(
         *     path="/privacy-policy",
         *     summary="Get the privacy policy content for the Flutter app",
         *     tags={"PrivacyPolicy"},
         *     @OA\Response(response=200, description="Privacy policy content.")
         * )
         */
    public function get()
    {
        $content = PrivacyPolicy::firstOrCreate(
            ['id' => 1],
            ['title' => 'Privacy Policy', 'content' => 'Welcome! Content is being updated.']
        );
        return response()->json($content);
    }

    // Admin method to update content
        /**
         * @OA\Put(
         *     path="/privacy-policy",
         *     summary="Update the privacy policy content (admin)",
         *     tags={"PrivacyPolicy"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"title","content"},
         *             @OA\Property(property="title", type="string"),
         *             @OA\Property(property="content", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Privacy Policy updated successfully."),
         *     @OA\Response(response=422, description="Validation error.")
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

        $content = PrivacyPolicy::updateOrCreate(
            ['id' => 1],
            $request->only(['title', 'content'])
        );

        return response()->json(['message' => 'Privacy Policy updated successfully.', 'data' => $content]);
    }
}
