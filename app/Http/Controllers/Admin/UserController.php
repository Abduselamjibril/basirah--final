<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Reset a user's password to a default value ('00000000').
     *
     * @param \App\Models\User $user
     * @return \Illuminate\Http\JsonResponse
     */
        /**
         * @OA\Post(
         *     path="/admin/users/{user}/reset-password",
         *     summary="Reset a user's password to default",
         *     tags={"AdminUser"},
         *     @OA\Parameter(
         *         name="user",
         *         in="path",
         *         required=true,
         *         description="User ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Password reset successful")
         * )
         */
    public function resetPassword(User $user): JsonResponse
    {
        // The default password
        $defaultPassword = '00000000';

        $user->password = Hash::make($defaultPassword);
        $user->save();

        return response()->json(['message' => "Password for user {$user->first_name} has been reset."]);
    }
}
