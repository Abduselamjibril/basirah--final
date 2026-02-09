<?php

namespace App\Http\Controllers;

use App\Models\ContactInformation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ContactInformationController extends Controller
{
    // Public method for Flutter App
        /**
         * @OA\Get(
         *     path="/contact-information",
         *     summary="Get contact information",
         *     tags={"ContactInformation"},
         *     @OA\Response(response=200, description="Contact information returned")
         * )
         */
    public function get()
    {
        $info = ContactInformation::firstOrCreate(
            ['id' => 1],
            ['phone_number' => 'Not Available', 'email' => 'Not Available']
        );
        return response()->json($info);
    }

    // Admin method to update info
        /**
         * @OA\Put(
         *     path="/contact-information",
         *     summary="Update contact information",
         *     tags={"ContactInformation"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"phone_number","email"},
         *             @OA\Property(property="phone_number", type="string"),
         *             @OA\Property(property="email", type="string", format="email")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Contact Information updated successfully."),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */
    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string|max:255',
            'email' => 'required|email|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $info = ContactInformation::updateOrCreate(
            ['id' => 1],
            $request->only(['phone_number', 'email'])
        );

        return response()->json(['message' => 'Contact Information updated successfully.', 'data' => $info]);
    }
}
