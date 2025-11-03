<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Firebase Project ID
    |--------------------------------------------------------------------------
    |
    | The project ID is a unique string used to differentiate your Firebase
    | project from others. You can find it in the project settings of
    | the Firebase console.
    |
    */
    'project_id' => env('FIREBASE_PROJECT_ID'),

    /*
    |--------------------------------------------------------------------------
    | Firebase Web API Key
    |--------------------------------------------------------------------------
    |
    | The web API key is used to identify your project when interacting with
    | Firebase services from a web client. You can find it in the project
    | settings of the Firebase console.
    |
    */
    'web_api_key' => env('FIREBASE_WEB_API_KEY'),

    /*
    |--------------------------------------------------------------------------
    | Firebase Service Account
    |--------------------------------------------------------------------------
    |
    | The Firebase service account is used to authenticate your application
    | when accessing Firebase services from the server. You can download
    | the service account JSON file from the Firebase console.
    |
    | You can also specify the path to the credentials file directly.
    |
    */
    'credentials' => env('FIREBASE_CREDENTIALS'),

    /*
    |--------------------------------------------------------------------------
    | Firebase Authentication
    |--------------------------------------------------------------------------
    |
    | Here you can configure the settings for Firebase Authentication.
    |
    */
    'auth' => [
        'tenant_id' => env('FIREBASE_AUTH_TENANT_ID'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Firebase Realtime Database
    |--------------------------------------------------------------------------
    |
    | Here you can configure the settings for the Firebase Realtime Database.
    |
    */
    'database' => [
        'uri' => env('FIREBASE_DATABASE_URI'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Firebase Dynamic Links
    |--------------------------------------------------------------------------
    |
    | Here you can configure the settings for Firebase Dynamic Links.
    |
    */
    'dynamic_links' => [
        'default_domain' => env('FIREBASE_DYNAMIC_LINKS_DEFAULT_DOMAIN'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Firebase Cloud Storage
    |--------------------------------------------------------------------------
    |
    | Here you can configure the settings for Firebase Cloud Storage.
    |
    */
    'storage' => [
        'default_bucket' => env('FIREBASE_STORAGE_DEFAULT_BUCKET'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Firebase Cloud Messaging
    |--------------------------------------------------------------------------
    |
    | Here you can configure the settings for Firebase Cloud Messaging.
    |
    */
    'messaging' => [
        'default_notification_channel_id' => env('FIREBASE_MESSAGING_DEFAULT_NOTIFICATION_CHANNEL_ID'),
        'default_notification_image_url' => env('FIREBASE_MESSAGING_DEFAULT_NOTIFICATION_IMAGE_URL'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Caching
    |--------------------------------------------------------------------------
    |
    | Here you can configure the cache store that is used to store
    | auto-discovered Google API Public Keys.
    |
    | You can choose any of the cache stores your application has configured.
    |
    */
    'cache_store' => env('FIREBASE_CACHE_STORE', 'file'),

    /*
    |--------------------------------------------------------------------------
    | Logging
    |--------------------------------------------------------------------------
    |
    | Here you can configure the logging channels that are used to log
    | information about the SDK's behavior.
    |
    | You can choose any of the logging channels your application has configured.
    |
    */
    'logging' => [
        'channel' => env('FIREBASE_LOG_CHANNEL'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Debugging
    |--------------------------------------------------------------------------
    |
    | When set to true, the SDK will log more information about its behavior.
    |
    | You can also set the log level to "debug" in your `config/logging.php`
    | file to see the logs.
    |
    */
    'debug' => env('FIREBASE_DEBUG', false),
];