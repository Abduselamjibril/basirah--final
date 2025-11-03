<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ValidateToken
{
    public function handle(Request $request, Closure $next)
    {
        // Retrieve the token from the Authorization header
        $token = $request->bearerToken();

        if (!$token) {
            return response()->json(['message' => 'Token not provided.'], 401);
        }

        // Attempt to authenticate the user via token using the 'api' guard
        $user = Auth::guard('api')->user();

        if (!$user) {
            return response()->json(['message' => 'Invalid token.'], 401);
        }

        // Optionally: Set user information in the request for later use
        $request->attributes->set('user', $user);

        // Allow the request to proceed
        return $next($request);
    }
}
