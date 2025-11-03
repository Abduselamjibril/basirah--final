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
    public function index()
    {
        // Return users with their permissions eager-loaded
        $users = AdminUser::with('permissions:id,name,display_name')->get();
        return response()->json($users);
    }
    
    // List all available permissions
    public function getPermissions()
    {
        return response()->json(Permission::all());
    }

    // Create a new regular admin user
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
    public function destroy(AdminUser $user)
    {
        if ($user->is_super_admin) {
            return response()->json(['message' => 'Super admins cannot be deleted.'], 403);
        }

        $user->delete();

        return response()->json(null, 204);
    }
}