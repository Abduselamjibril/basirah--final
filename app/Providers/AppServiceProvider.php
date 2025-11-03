<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use GuzzleHttp\Client;
use GuzzleHttp\ClientInterface;
use Kreait\Firebase;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\ApiClient;
use Psr\Http\Message\RequestFactoryInterface;
use Nyholm\Psr7\Factory\Psr17Factory;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->bindPsr17Factories();
        $this->bindGuzzleClient();
        $this->bindFirebaseServices();
    }

    protected function bindPsr17Factories(): void
    {
        $this->app->singleton(RequestFactoryInterface::class, function () {
            return new Psr17Factory();
        });
    }

    protected function bindGuzzleClient(): void
    {
        $this->app->bind(ClientInterface::class, function () {
            return new Client([
                'timeout' => 30,
                'verify' => $this->app->environment('production'),
                'http_errors' => false,
            ]);
        });
    }

    protected function bindFirebaseServices(): void
    {
        $this->app->bind(ApiClient::class, function ($app) {
            return new ApiClient(
                $app->make(ClientInterface::class),
                config('services.firebase.project_id'),
                $app->make(RequestFactoryInterface::class)
            );
        });

        $this->app->singleton(Firebase::class, function () {
            $credentialsPath = storage_path(
                config('services.firebase.credentials')
            );

            if (!file_exists($credentialsPath)) {
                throw new \RuntimeException("Firebase credentials file not found at: {$credentialsPath}");
            }

            return (new Factory)
                ->withServiceAccount($credentialsPath)
                ->withDatabaseUri(config('services.firebase.database_url'))
                ->create();
        });

        $this->app->alias(Firebase::class, 'firebase');
    }
}