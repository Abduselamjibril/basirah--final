<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
   public function up(): void
{
    Schema::create('assigned_gifts', function (Blueprint $table) {
        $table->id();
        $table->foreignId('gift_purchase_id')->constrained('gift_purchases')->onDelete('cascade');
        $table->foreignId('recipient_user_id')->constrained('users')->onDelete('cascade');
        $table->foreignId('assigned_by_admin_id')->constrained('admin_users')->onDelete('cascade');
        $table->timestamps();
    });
}

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('assigned_gifts');
    }
};
