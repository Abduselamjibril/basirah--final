<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FcmController extends Controller
{
    /**
     * Update the FCM token for the authenticated user.
     */
    public function updateToken(Request $request)
    {
        $request->validate([
            'fcm_token' => 'required|string',
        ]);

        // Assuming your users are authenticated via Sanctum/Passport
        $user = Auth::user();

        if ($user) {
            $user->fcm_token = $request->fcm_token;
            $user->save();
            return response()->json(['message' => 'FCM token updated successfully.']);
        }

        return response()->json(['message' => 'User not authenticated.'], 401);
    }
}
