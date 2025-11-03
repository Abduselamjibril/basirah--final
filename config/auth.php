<?php

return [

    'defaults' => [
        'guard' => env('AUTH_GUARD', 'web'), // Keep as 'web' for regular users
        'passwords' => env('AUTH_PASSWORD_BROKER', 'users'),
    ],

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
        'admin' => [
            'driver' => 'jwt', // Use JWT for admin authentication
            'provider' => 'admin_users',
        ],
        'api' => [ // Updated API guard to use Sanctum
            'driver' => 'sanctum', // Use Sanctum for API authentication
            'provider' => 'users',
        ],
    ],

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => env('AUTH_MODEL', App\Models\User::class),
        ],
        'admin_users' => [
            'driver' => 'eloquent',
            'model' => App\Models\AdminUser::class, // Ensure this points to AdminUser
        ],
    ],

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => env('AUTH_PASSWORD_RESET_TOKEN_TABLE', 'password_reset_tokens'),
            'expire' => 60,
            'throttle' => 60,
        ],
        'admin_users' => [
            'provider' => 'admin_users',
            'table' => 'admin_password_reset_tokens',
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    'password_timeout' => env('AUTH_PASSWORD_TIMEOUT', 10800),

];
