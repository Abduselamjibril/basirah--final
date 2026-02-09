<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class UserListController extends Controller
{
    // Fetch all users
        /**
         * @OA\Get(
         *     path="/users",
         *     summary="Fetch all users",
         *     tags={"UserList"},
         *     @OA\Response(response=200, description="List of users.")
         * )
         */
    public function index()
    {
        // You can choose to return only the fields you want to display
        return response()->json(User::select('id', 'first_name', 'last_name', 'phone_number','is_subscribed','subscription_expires_at')->get());
    }

    // Delete a user
        /**
         * @OA\Delete(
         *     path="/users/{id}",
         *     summary="Delete a user",
         *     tags={"UserList"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="User ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=204, description="User deleted successfully."),
         *     @OA\Response(response=404, description="User not found.")
         * )
         */
    public function destroy($id)
    {
        $user = User::findOrFail($id);
        $user->delete();
        return response()->json(null, 204);
    }
}
