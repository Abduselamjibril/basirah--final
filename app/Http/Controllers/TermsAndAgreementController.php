<?php

namespace App\Http\Controllers;

use App\Models\TermsAndAgreement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class TermsAndAgreementController extends Controller
{
    // Public method for Flutter App
        /**
         * @OA\Get(
         *     path="/terms-and-agreement",
         *     summary="Get the terms and agreement content for the Flutter app",
         *     tags={"TermsAndAgreement"},
         *     @OA\Response(response=200, description="Terms and agreement content.")
         * )
         */
    public function get()
    {
        $content = TermsAndAgreement::firstOrCreate(
            ['id' => 1],
            ['title' => 'Terms and Agreement', 'content' => 'Welcome! Content is being updated.']
        );
        return response()->json($content);
    }

    // Admin method to update content
        /**
         * @OA\Put(
         *     path="/terms-and-agreement",
         *     summary="Update the terms and agreement content (admin)",
         *     tags={"TermsAndAgreement"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"title","content"},
         *             @OA\Property(property="title", type="string"),
         *             @OA\Property(property="content", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Terms and Agreement updated successfully."),
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

        $content = TermsAndAgreement::updateOrCreate(
            ['id' => 1],
            $request->only(['title', 'content'])
        );

        return response()->json(['message' => 'Terms and Agreement updated successfully.', 'data' => $content]);
    }
}
