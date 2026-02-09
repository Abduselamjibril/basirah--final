<?php

namespace App\Http\Docs;

use OpenApi\Attributes as OA;

#[OA\Info(
    title: "Basirah API Documentation",
    version: "1.0.0",
    description: "API documentation for Basirah backend."
)]
#[OA\Server(url: 'http://localhost:8000/api')]
#[OA\Tag(name: "Auth", description: "Authentication related endpoints")] // Add this line
class ApiDoc
{
    #[OA\Get(
        path: '/',
        summary: 'API Root',
        responses: [
            new OA\Response(response: 200, description: 'API is running')
        ]
    )]
    public function index() {}
}
