<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Permission;
use Illuminate\Support\Facades\DB;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        // Clear the table to avoid duplicates on re-seeding
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        Permission::truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        $permissions = [
            // Core
            ['name' => 'view_dashboard', 'display_name' => 'View Dashboard'],
            ['name' => 'manage_profile', 'display_name' => 'Manage Own Profile'],
            ['name' => 'manage_roles', 'display_name' => 'Manage Roles & Permissions'],

            // Sidebar Items
            ['name' => 'view_notifications', 'display_name' => 'View Notifications'],
            ['name' => 'manage_faq', 'display_name' => 'Manage FAQ'],
            ['name' => 'manage_gifts', 'display_name' => 'Manage Gift Purchases'],
            ['name' => 'manage_uploads_course', 'display_name' => 'Upload/Manage Courses'],
            ['name' => 'manage_uploads_surah', 'display_name' => 'Upload/Manage Surahs'],
            ['name' => 'manage_uploads_story', 'display_name' => 'Upload/Manage Stories'],
            ['name' => 'manage_uploads_deeper_look', 'display_name' => 'Upload/Manage Deeper Look'],
            ['name' => 'manage_uploads_commentary', 'display_name' => 'Upload/Manage Commentary'],
            ['name' => 'manage_app_pages', 'display_name' => 'Manage App Pages (About, Terms, etc.)'],
            ['name' => 'view_main_website', 'display_name' => 'View Main Website Link']

        ];

        foreach ($permissions as $permission) {
            Permission::create($permission);
        }
    }
}