<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('revenue_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('source_type'); // e.g., 'ManualPayment', 'GiftPurchase'
            $table->unsignedBigInteger('source_id');
            $table->decimal('amount', 10, 2);
            $table->string('plan_duration'); // 'six_month' or 'yearly'
            $table->timestamp('processed_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('revenue_transactions');
    }
};