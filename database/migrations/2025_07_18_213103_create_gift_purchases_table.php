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
    Schema::create('gift_purchases', function (Blueprint $table) {
        $table->id();
        $table->foreignId('gifter_user_id')->constrained('users')->onDelete('cascade');
        $table->string('plan_duration'); // 'six_month' or 'yearly'
        $table->integer('quantity_purchased');
        $table->integer('quantity_remaining')->default(0); // Initially 0 until approved
        $table->decimal('total_price', 10, 2);
        $table->string('transaction_id');
        $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
        $table->timestamps();
    });
}
    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('gift_purchases');
    }
};
