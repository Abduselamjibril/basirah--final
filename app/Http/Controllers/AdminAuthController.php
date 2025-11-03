<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\AdminUser;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule; // <-- Import this

class AdminAuthController extends Controller
{
    // ... login method (no change) ...
    public function login(Request $request)
    {
        $credentials = $request->only('email', 'password');
        if (!$token = auth(guard: 'admin')->attempt($credentials)) {
            return response()->json(['message' => 'Invalid credentials'], 401);
        }
        return response()->json(['message' => 'Login successful', 'token' => $token,]);
    }

    // Get Admin Profile - Updated to load permissions
    public function profile()
    {
        return response()->json(auth('admin')->user()->load('permissions:id,name,display_name'));
    }
    
    // NEW: Update own profile (for Super Admins)
    public function updateProfile(Request $request)
    {
        /** @var \App\Models\AdminUser $user */
        $user = auth('admin')->user();

        // Security Check: Only Super Admins can edit their profile details
        if (!$user->is_super_admin) {
            return response()->json(['message' => 'Only super admins can edit their profile.'], 403);
        }

        $request->validate([
            'name' => 'required|string|max:255',
            'email' => [
                'required',
                'string',
                'email',
                'max:255',
                Rule::unique('admin_users')->ignore($user->id),
            ],
        ]);

        $user->update($request->only('name', 'email'));
        
        return response()->json(['message' => 'Profile updated successfully.', 'user' => $user]);
    }

    // ... changePassword and logout methods (no change) ...
    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'new_password' => 'required|string|min:8|confirmed',
        ]);
        /** @var \App\Models\AdminUser $admin */
        $admin = auth('admin')->user();
        if (!Hash::check($request->current_password, $admin->password)) {
            return response()->json(['message' => 'Current password is incorrect'], 400);
        }
        $admin->update(['password' => Hash::make($request->new_password)]);
        return response()->json(['message' => 'Password updated successfully']);
    }

    public function logout()
    {
        auth('admin')->logout();
        return response()->json(['message' => 'Logged out successfully']);
    }
}