<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use App\Models\ActiveDevice;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Config;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Mail;
use App\Mail\PasswordResetMail;
use Carbon\Carbon;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    /**
     * @OA\Post(
     *     path="/register",
     *     summary="Register a new user",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"first_name","last_name","phone_number","password","password_confirmation","device_id"},
     *             @OA\Property(property="first_name", type="string"),
     *             @OA\Property(property="last_name", type="string"),
     *             @OA\Property(property="email", type="string", format="email"),
     *             @OA\Property(property="phone_number", type="string"),
     *             @OA\Property(property="password", type="string"),
     *             @OA\Property(property="password_confirmation", type="string"),
     *             @OA\Property(property="device_id", type="string"),
     *             @OA\Property(property="device_name", type="string")
     *         )
     *     ),
     *     @OA\Response(response=201, description="User registered successfully"),
     *     @OA\Response(response=422, description="Validation error")
     * )
     */
    public function register(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => 'nullable|string|email|max:255|unique:users',
            'phone_number' => 'required|string|regex:/^[0-9]+$/|unique:users,phone_number',
            'password' => 'required|string|min:8|confirmed',
            'device_id' => 'required|string|max:255',
            'device_name' => 'nullable|string|max:255',
        ], [
            'phone_number.unique' => 'The phone number is already registered.',
            'email.unique' => 'The email address is already registered.',
            'device_id.required' => 'Device identifier is required.',
        ]);

        if ($validator->fails()) {
            Log::error('Validation Errors during registration', ['errors' => $validator->errors()->all()]);
            return response()->json(['errors' => $validator->errors()], 422);
        }

        try {
            $user = User::create([
                'first_name' => $request->first_name,
                'last_name' => $request->last_name,
                'email' => $request->email,
                'phone_number' => $request->phone_number,
                'password' => Hash::make($request->password),
            ]);

            $tokenName = $request->input('device_name', $request->input('device_id'));
            $newSanctumToken = $user->createToken($tokenName);
            $plainTextToken = $newSanctumToken->plainTextToken;
            $tokenId = $newSanctumToken->accessToken->id;

            ActiveDevice::create([
                'user_id' => $user->id,
                'device_id' => $request->device_id,
                'token_id' => $tokenId,
                'user_agent' => $request->userAgent(),
                'ip_address' => $request->ip(),
                'last_active_at' => now(),
            ]);

        } catch (\Exception $e) {
            Log::error('User registration failed', ['error' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
            return response()->json(['message' => 'Registration failed. Please try again.'], 500);
        }

        return response()->json([
            'message' => 'User registered successfully',
            'token' => $plainTextToken,
            'user' => [
                'id' => $user->id,
                'first_name' => $user->first_name,
                'last_name' => $user->last_name,
                'phone_number' => $user->phone_number,
                'email' => $user->email,
                'is_subscribed_and_active' => ($user instanceof \App\Models\User) ? $user->isSubscribedAndActive() : false,
            ],
        ], 201);
    }

    /**
     * @OA\Post(
     *     path="/login",
     *     summary="Login user",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"phone_number","password","device_id"},
     *             @OA\Property(property="phone_number", type="string"),
     *             @OA\Property(property="password", type="string"),
     *             @OA\Property(property="device_id", type="string"),
     *             @OA\Property(property="device_name", type="string")
     *         )
     *     ),
     *     @OA\Response(response=200, description="Login successful"),
     *     @OA\Response(response=401, description="Invalid login attempt"),
     *     @OA\Response(response=429, description="Too many login attempts")
     * )
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
            'password' => 'required|string',
            'device_id' => 'required|string|max:255',
            'device_name' => 'nullable|string|max:255',
        ],[
            'device_id.required' => 'Device identifier is required.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $key = 'login-attempt-' . $request->ip();
        if (RateLimiter::tooManyAttempts($key, 5)) {
            return response()->json(['message' => 'Too many login attempts. Try again later.'], 429);
        }

        $user = User::where('phone_number', $request->phone_number)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            RateLimiter::hit($key);
            return response()->json(['message' => 'Invalid login attempt'], 401);
        }

        RateLimiter::clear($key);

        $maxDevices = Config::get('auth_limits.max_devices', 2);
        $userActiveDevices = ActiveDevice::where('user_id', $user->id)
                                        ->orderBy('last_active_at', 'asc')
                                        ->get();

        if ($userActiveDevices->count() >= $maxDevices) {
            $devicesToLogoutCount = ($userActiveDevices->count() - $maxDevices) + 1;
            $oldestDevices = $userActiveDevices->take($devicesToLogoutCount);

            foreach ($oldestDevices as $oldDevice) {
                $tokenInstance = $user->tokens()->where('id', $oldDevice->token_id)->first();
                if ($tokenInstance) {
                    $tokenInstance->delete();
                }
                $oldDevice->delete();
                Log::info('Device limit exceeded: Logged out device.', [
                    'user_id' => $user->id,
                    'device_id_logged_out' => $oldDevice->device_id,
                    'token_id_revoked' => $oldDevice->token_id
                ]);
            }
        }

        $tokenName = $request->input('device_name', $request->input('device_id'));
        $newSanctumToken = $user->createToken($tokenName);
        $plainTextToken = $newSanctumToken->plainTextToken;
        $tokenId = $newSanctumToken->accessToken->id;

        ActiveDevice::create([
            'user_id' => $user->id,
            'device_id' => $request->device_id,
            'token_id' => $tokenId,
            'user_agent' => $request->userAgent(),
            'ip_address' => $request->ip(),
            'last_active_at' => now(),
        ]);

        return response()->json([
            'message' => 'Login successful',
            'token' => $plainTextToken,
            'user' => [
                'id' => $user->id,
                'first_name' => $user->first_name,
                'last_name' => $user->last_name,
                'phone_number' => $user->phone_number,
                'email' => $user->email,
                'is_subscribed_and_active' => ($user instanceof \App\Models\User) ? $user->isSubscribedAndActive() : false,
            ],
        ], 200);
    }

    /**
     * @OA\Post(
     *     path="/logout",
     *     summary="Logout user",
     *     tags={"Auth"},
     *     @OA\Response(response=200, description="Logged out successfully")
     * )
     */
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        $currentToken = $user->currentAccessToken();

        if ($currentToken) {
            ActiveDevice::where('token_id', $currentToken->id)
                        ->where('user_id', $user->id)
                        ->delete();

            $currentToken->delete();
            Log::info('User logged out and device session removed.', ['user_id' => $user->id, 'token_id' => $currentToken->id]);
        } else {
             Log::warning('Logout attempt without a current access token.', ['user_id' => $user?->id]);
        }

        return response()->json(['message' => 'Logged out successfully'], 200);
    }

    /**
     * @OA\Post(
     *     path="/forgot-password",
     *     summary="Send password reset OTP to email",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email"},
     *             @OA\Property(property="email", type="string", format="email")
     *         )
     *     ),
     *     @OA\Response(response=200, description="Reset code sent if account found")
     * )
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), ['email' => 'required|email|exists:users,email']);

        if ($validator->fails()) {
            return response()->json(['message' => 'If a matching account was found, a reset code has been sent to your email.'], 200);
        }

        $user = User::where('email', $request->email)->first();
        $otp = random_int(100000, 999999);
        $user->otp_code = $otp;
        $user->otp_expires_at = now()->addMinutes(10);
        $user->save();

        try {
            Mail::to($user->email)->send(new PasswordResetMail((string)$otp));
        } catch (\Exception $e) {
            Log::error('Mail sending failed for password reset', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Could not send reset code. Please try again later.'], 500);
        }

        return response()->json(['message' => 'If a matching account was found, a reset code has been sent to your email.'], 200);
    }

    /**
     * @OA\Post(
     *     path="/verify-otp",
     *     summary="Verify OTP for password reset",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email","otp"},
     *             @OA\Property(property="email", type="string", format="email"),
     *             @OA\Property(property="otp", type="integer")
     *         )
     *     ),
     *     @OA\Response(response=200, description="OTP verified successfully"),
     *     @OA\Response(response=401, description="Invalid OTP or expired")
     * )
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email|exists:users,email',
            'otp' => 'required|numeric|digits:6',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user->otp_code || $user->otp_code !== $request->otp) {
            return response()->json(['message' => 'Invalid OTP.'], 401);
        }

        if (Carbon::now()->isAfter($user->otp_expires_at)) {
            return response()->json(['message' => 'OTP has expired.'], 401);
        }

        return response()->json(['message' => 'OTP verified successfully.'], 200);
    }

    /**
     * @OA\Post(
     *     path="/reset-password",
     *     summary="Reset password using OTP",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email","otp","password","password_confirmation"},
     *             @OA\Property(property="email", type="string", format="email"),
     *             @OA\Property(property="otp", type="integer"),
     *             @OA\Property(property="password", type="string"),
     *             @OA\Property(property="password_confirmation", type="string")
     *         )
     *     ),
     *     @OA\Response(response=200, description="Password reset successfully"),
     *     @OA\Response(response=401, description="Invalid OTP or expired")
     * )
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email|exists:users,email',
            'otp' => 'required|numeric|digits:6',
            'password' => 'required|string|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::where('email', $request->email)->where('otp_code', $request->otp)->first();

        if (!$user) {
            return response()->json(['message' => 'Invalid OTP or email.'], 401);
        }
        if (Carbon::now()->isAfter($user->otp_expires_at)) {
            return response()->json(['message' => 'OTP has expired.'], 401);
        }

        $user->password = Hash::make($request->password);
        $user->otp_code = null;
        $user->otp_expires_at = null;
        $user->save();

        return response()->json(['message' => 'Password has been reset successfully. Please login.'], 200);
    }

    /**
     * @OA\Post(
     *     path="/change-password",
     *     summary="Change password for authenticated user",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"current_password","password","password_confirmation"},
     *             @OA\Property(property="current_password", type="string"),
     *             @OA\Property(property="password", type="string"),
     *             @OA\Property(property="password_confirmation", type="string")
     *         )
     *     ),
     *     @OA\Response(response=200, description="Password changed successfully"),
     *     @OA\Response(response=401, description="Current password does not match")
     * )
     */
    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();

        $validator = Validator::make($request->all(), [
            'current_password' => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Current password does not match.'], 401);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        return response()->json(['message' => 'Password changed successfully.'], 200);
    }

    /**
     * @OA\Put(
     *     path="/profile",
     *     summary="Update user profile",
     *     tags={"Auth"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"first_name","last_name","phone_number"},
     *             @OA\Property(property="first_name", type="string"),
     *             @OA\Property(property="last_name", type="string"),
     *             @OA\Property(property="email", type="string", format="email"),
     *             @OA\Property(property="phone_number", type="string")
     *         )
     *     ),
     *     @OA\Response(response=200, description="Profile updated successfully")
     * )
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();

        $validator = Validator::make($request->all(), [
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => [
                'nullable', 'string', 'email', 'max:255', Rule::unique('users')->ignore($user->id),
            ],
            'phone_number' => [
                'required', 'string', 'regex:/^[0-9]+$/', Rule::unique('users')->ignore($user->id),
            ],
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        try {
            $user->first_name = $request->first_name;
            $user->last_name = $request->last_name;
            $user->email = $request->email;
            $user->phone_number = $request->phone_number;
            $user->save();
        } catch (\Exception $e) {
            Log::error('User profile update failed', ['error' => $e->getMessage(), 'user_id' => $user->id]);
            return response()->json(['message' => 'Profile update failed. Please try again.'], 500);
        }

        return response()->json([
            'message' => 'Profile updated successfully.',
            'user' => $user->fresh()
        ], 200);
    }
}
