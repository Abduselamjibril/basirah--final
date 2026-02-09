<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FcmController extends Controller
{
    /**
     * Update the FCM token for the authenticated user.
     */
        /**
         * @OA\Post(
         *     path="/fcm/update-token",
         *     summary="Update the FCM token for the authenticated user",
         *     tags={"Fcm"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"fcm_token"},
         *             @OA\Property(property="fcm_token", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="FCM token updated successfully."),
         *     @OA\Response(response=401, description="User not authenticated.")
         * )
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
