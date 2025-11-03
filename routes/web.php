<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
    
});
Route::get('/debug-firebase-check', function () {
    // 1. Force clear the config cache just for this request
    \Illuminate\Support\Facades\Artisan::call('config:clear');

    // 2. Get values directly from the system
    $envValue = env('FIREBASE_CREDENTIALS');
    $configValue = config('firebase.credentials');
    $phpVersion = phpversion();
    $sodiumLoaded = extension_loaded('sodium');

    // 3. Try to create the Guzzle Client manually to see if it works here
    $guzzleClient = null;
    $guzzleError = 'Not Attempted';
    try {
        $guzzleClient = new \GuzzleHttp\Client();
        $guzzleError = 'No error. Guzzle client created successfully.';
    } catch (\Throwable $e) {
        $guzzleError = $e->getMessage();
    }


    // 4. Display all the information
    dd([
        'DIAGNOSIS REPORT' => '--- Check these values carefully ---',
        '1. PHP Version (Web Server)' => $phpVersion,
        '2. Sodium Extension Loaded?' => $sodiumLoaded,
        '3. .env value for FIREBASE_CREDENTIALS' => $envValue,
        '4. Config value from config(\'firebase.credentials\')' => $configValue,
        '5. Credentials File Exists?' => file_exists(base_path($envValue)) ? 'YES' : 'NO - THIS IS A BIG PROBLEM',
        '6. Can Guzzle be created?' => [
            'Client Object' => $guzzleClient,
            'Error Message' => $guzzleError
        ],
        'NEXT STEP' => 'Paste a screenshot of this entire page in your reply.'
    ]);
});
