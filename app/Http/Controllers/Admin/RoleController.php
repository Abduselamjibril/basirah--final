<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\Permission;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class RoleController extends Controller
{
    // List all admin users
        /**
         * @OA\Get(
         *     path="/admin/admin-users",
         *     summary="List all admin users",
         *     tags={"Role"},
         *     @OA\Response(response=200, description="List of admin users")
         * )
         */
    public function index()
    {
        // Return users with their permissions eager-loaded
        $users = AdminUser::with('permissions:id,name,display_name')->get();
        return response()->json($users);
    }

    // List all available permissions
        /**
         * @OA\Get(
         *     path="/admin/permissions",
         *     summary="List all available permissions",
         *     tags={"Role"},
         *     @OA\Response(response=200, description="List of permissions")
         * )
         */
    public function getPermissions()
    {
        return response()->json(Permission::all());
    }

    // Create a new regular admin user
        /**
         * @OA\Post(
         *     path="/admin/admin-users",
         *     summary="Create a new admin user",
         *     tags={"Role"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"name","email","permissions"},
         *             @OA\Property(property="name", type="string"),
         *             @OA\Property(property="email", type="string", format="email"),
         *             @OA\Property(property="permissions", type="array", @OA\Items(type="integer"))
         *         )
         *     ),
         *     @OA\Response(response=201, description="Admin user created")
         * )
         */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:admin_users',
            'permissions' => 'required|array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        $user = AdminUser::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make('00000000'), // Default password
            'is_super_admin' => false, // New users are never super admins
        ]);

        $user->permissions()->sync($request->permissions);

        return response()->json($user->load('permissions'), 201);
    }

    // Update only the permissions of a regular admin
        /**
         * @OA\Put(
         *     path="/admin/admin-users/{user}/permissions",
         *     summary="Update permissions of an admin user",
         *     tags={"Role"},
         *     @OA\Parameter(
         *         name="user",
         *         in="path",
         *         required=true,
         *         description="Admin user ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"permissions"},
         *             @OA\Property(property="permissions", type="array", @OA\Items(type="integer"))
         *         )
         *     ),
         *     @OA\Response(response=200, description="Permissions updated"),
         *     @OA\Response(response=403, description="Cannot modify a super admin's permissions")
         * )
         */
    public function updatePermissions(Request $request, AdminUser $user)
    {
        if ($user->is_super_admin) {
            return response()->json(['message' => 'Cannot modify a super admin\'s permissions.'], 403);
        }

        $request->validate([
            'permissions' => 'required|array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        $user->permissions()->sync($request->permissions);

        return response()->json($user->load('permissions'));
    }

    // Delete a regular admin user
        /**
         * @OA\Delete(
         *     path="/admin/admin-users/{user}",
         *     summary="Delete an admin user",
         *     tags={"Role"},
         *     @OA\Parameter(
         *         name="user",
         *         in="path",
         *         required=true,
         *         description="Admin user ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=204, description="Admin user deleted"),
         *     @OA\Response(response=403, description="Super admins cannot be deleted")
         * )
         */
    public function destroy(AdminUser $user)
    {
        if ($user->is_super_admin) {
            return response()->json(['message' => 'Super admins cannot be deleted.'], 403);
        }

        $user->delete();

        return response()->json(null, 204);
    }
}
