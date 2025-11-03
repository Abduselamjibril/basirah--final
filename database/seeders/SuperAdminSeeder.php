<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\AdminUser;
use App\Models\Permission;
use Illuminate\Support\Facades\Hash;

class SuperAdminSeeder extends Seeder
{
    public function run(): void
    {
        // Get all permissions. Super Admins get everything by default.
        $allPermissions = Permission::pluck('id');

        // Create Basirah Super Admin
        $basirah = AdminUser::updateOrCreate(
            ['email' => 'basirah@gmail.com'],
            [
                'name' => 'Basirah Super Admin',
                'password' => Hash::make('00000000'),
                'is_super_admin' => true,
            ]
        );
        $basirah->permissions()->sync($allPermissions);

        // Create Skylink Super Admin
        $skylink = AdminUser::updateOrCreate(
            ['email' => 'skylink@gmail.com'],
            [
                'name' => 'Skylink Super Admin',
                'password' => Hash::make('00000000'),
                'is_super_admin' => true,
            ]
        );
        // Example: If Skylink should have different permissions, you can specify them.
        // For now, we give them all permissions too.
        $skylink->permissions()->sync($allPermissions);
    }
}