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
        Schema::table('users', function (Blueprint $table) {
            // Add email column right after last_name, ensuring it's unique
            $table->string('email')->unique()->after('last_name');

            // Add columns for OTP functionality, allowing them to be null
            $table->string('otp_code')->nullable()->after('password');
            $table->timestamp('otp_expires_at')->nullable()->after('otp_code');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Drop the columns if the migration is rolled back
            $table->dropColumn(['email', 'otp_code', 'otp_expires_at']);
        });
    }
};
