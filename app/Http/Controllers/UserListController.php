<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class UserListController extends Controller
{
    // Fetch all users
    public function index()
    {
        // You can choose to return only the fields you want to display
        return response()->json(User::select('id', 'first_name', 'last_name', 'phone_number','is_subscribed','subscription_expires_at')->get());
    }

    // Delete a user
    public function destroy($id)
    {
        $user = User::findOrFail($id);
        $user->delete();
        return response()->json(null, 204);
    }
}
