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
    public function resetPassword(User $user): JsonResponse
    {
        // The default password
        $defaultPassword = '00000000';
        
        $user->password = Hash::make($defaultPassword);
        $user->save();

        return response()->json(['message' => "Password for user {$user->first_name} has been reset."]);
    }
}