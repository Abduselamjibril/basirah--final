<?php

namespace App\Http\Controllers;

use App\Models\ContactInformation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ContactInformationController extends Controller
{
    // Public method for Flutter App
    public function get()
    {
        $info = ContactInformation::firstOrCreate(
            ['id' => 1],
            ['phone_number' => 'Not Available', 'email' => 'Not Available']
        );
        return response()->json($info);
    }

    // Admin method to update info
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