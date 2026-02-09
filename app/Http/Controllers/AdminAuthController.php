<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\AdminUser;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule; // <-- Import this

class AdminAuthController extends Controller
{
    // ... login method (no change) ...
        /**
         * @OA\Post(
         *     path="/admin/login",
         *     summary="Admin login",
         *     tags={"AdminAuth"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"email","password"},
         *             @OA\Property(property="email", type="string", format="email"),
         *             @OA\Property(property="password", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Login successful"),
         *     @OA\Response(response=401, description="Invalid credentials")
         * )
         */
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
        $user = auth('admin')->user();
        if (!$user instanceof \App\Models\AdminUser) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        $user->load('permissions:id,name,display_name');
        return response()->json($user);
    }
        /**
         * @OA\Get(
         *     path="/admin/profile",
         *     summary="Get admin profile",
         *     tags={"AdminAuth"},
         *     @OA\Response(response=200, description="Admin profile returned"),
         *     @OA\Response(response=401, description="Unauthorized")
         * )
         */

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
        /**
         * @OA\Put(
         *     path="/admin/profile",
         *     summary="Update admin profile (Super Admin only)",
         *     tags={"AdminAuth"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name","email"},
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="email", type="string", format="email")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Profile updated"),
         *     @OA\Response(response=403, description="Only super admins can edit their profile.")
         * )
         */

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
        /**
         * @OA\Post(
         *     path="/admin/change-password",
         *     summary="Change admin password",
         *     tags={"AdminAuth"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"current_password","new_password","new_password_confirmation"},
         *             @OA\Property(property="current_password", type="string"),
         *             @OA\Property(property="new_password", type="string"),
         *             @OA\Property(property="new_password_confirmation", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Password updated successfully"),
         *     @OA\Response(response=400, description="Current password is incorrect")
         * )
         */

    public function logout()
    {
        auth('admin')->logout();
        return response()->json(['message' => 'Logged out successfully']);
    }
        /**
         * @OA\Post(
         *     path="/admin/logout",
         *     summary="Admin logout",
         *     tags={"AdminAuth"},
         *     @OA\Response(response=200, description="Logged out successfully")
         * )
         */
}
