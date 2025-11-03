<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payouts', function (Blueprint $table) {
            $table->id();
            $table->decimal('amount_paid', 10, 2);
            $table->foreignId('requested_by_admin_id')->constrained('admin_users');
            $table->foreignId('reviewed_by_admin_id')->nullable()->constrained('admin_users');
            $table->enum('status', ['pending', 'approved', 'declined'])->default('pending');
            $table->timestamp('requested_at');
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payouts');
    }
};