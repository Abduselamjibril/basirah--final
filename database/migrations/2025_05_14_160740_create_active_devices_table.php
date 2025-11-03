<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('active_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('device_id'); // Unique ID from Flutter
            $table->unsignedBigInteger('token_id')->unique(); // ID of the Sanctum token
            $table->text('user_agent')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('last_active_at')->useCurrent(); // Set at login/registration
            $table->timestamps();

            $table->foreign('token_id')->references('id')->on('personal_access_tokens')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('active_devices');
    }
};
