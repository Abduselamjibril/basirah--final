<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('permission_admin_user', function (Blueprint $table) {
            $table->primary(['admin_user_id', 'permission_id']); // Composite primary key
            $table->foreignId('admin_user_id')->constrained('admin_users')->onDelete('cascade');
            $table->foreignId('permission_id')->constrained('permissions')->onDelete('cascade');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('permission_admin_user');
    }
};