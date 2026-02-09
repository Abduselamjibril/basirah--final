<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\PaymentRequest;
use App\Models\RevenueTransaction; // <-- ADD THIS IMPORT
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class PaymentRequestController extends Controller
{
    /**
     * Store a new manual payment request from the Flutter app.
     */
        /**
         * @OA\Post(
         *     path="/payment-requests",
         *     summary="Store a new manual payment request from the Flutter app",
         *     tags={"PaymentRequest"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"plan","transaction_id"},
         *             @OA\Property(property="plan", type="string", enum={"six_month","yearly"}),
         *             @OA\Property(property="transaction_id", type="string")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Payment request submitted for review."),
         *     @OA\Response(response=422, description="Validation error"),
         *     @OA\Response(response=500, description="Server error")
         * )
         */
    public function store(Request $request)
    {
        $validator = \Validator::make($request->all(), [
            'plan' => 'required|string|in:six_month,yearly',
            'transaction_id' => 'required|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = Auth::user();

        try {
            PaymentRequest::create([
                'user_id' => $user->id,
                'plan' => $request->plan,
                'transaction_id' => $request->transaction_id,
                'status' => 'pending',
            ]);

            return response()->json(['message' => 'Your payment request has been submitted for review.'], 201);

        } catch (\Exception $e) {
            Log::error('Failed to store manual payment request', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'An error occurred while submitting your request.'], 500);
        }
    }

    /**
     * Fetch all pending payment requests for the React admin panel.
     */
        /**
         * @OA\Get(
         *     path="/payment-requests",
         *     summary="Fetch all pending payment requests for the React admin panel",
         *     tags={"PaymentRequest"},
         *     @OA\Response(response=200, description="List of pending payment requests.")
         * )
         */
    public function index()
    {
        $pendingPayments = PaymentRequest::with('user:id,first_name,last_name,phone_number')
                                        ->where('status', 'pending')
                                        ->latest()
                                        ->get();

        return response()->json($pendingPayments);
    }

    /**
     * Approve a payment request from the React admin panel.
     */
        /**
         * @OA\Patch(
         *     path="/payment-requests/{id}/approve",
         *     summary="Approve a payment request from the React admin panel",
         *     tags={"PaymentRequest"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="PaymentRequest ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Payment approved successfully. User subscription is now active."),
         *     @OA\Response(response=409, description="Request already processed."),
         *     @OA\Response(response=404, description="Associated user not found.")
         * )
         */
    public function approve(PaymentRequest $paymentRequest)
    {
        if ($paymentRequest->status !== 'pending') {
            return response()->json(['message' => 'This request has already been processed.'], 409);
        }

        $user = $paymentRequest->user;
        if (!$user) {
            return response()->json(['message' => 'Associated user not found.'], 404);
        }

        // --- START OF UPDATED LOGIC ---

        // Define prices for revenue logging
        $prices = [
            'six_month' => 6000,
            'yearly'    => 12000,
        ];
        $amount = $prices[$paymentRequest->plan] ?? 0;

        // Correctly stack subscription durations
        $startDate = $user->subscription_expires_at && $user->subscription_expires_at->isFuture()
            ? $user->subscription_expires_at
            : Carbon::now();

        if ($paymentRequest->plan === 'yearly') {
            $user->subscription_expires_at = $startDate->copy()->addYear();
        } else { // 'six_month'
            $user->subscription_expires_at = $startDate->copy()->addMonths(6);
        }
        $user->is_subscribed = true;
        $user->save();

        // Update the request's status to 'approved'
        $paymentRequest->status = 'approved';
        $paymentRequest->save();

        // ** NEW: Create a permanent revenue transaction record **
        RevenueTransaction::create([
            'source_type'  => 'ManualPayment',
            'source_id'    => $paymentRequest->id,
            'amount'       => $amount,
            'plan_duration'=> $paymentRequest->plan,
            'processed_at' => Carbon::now(),
        ]);

        // --- END OF UPDATED LOGIC ---

        Log::info('Payment request approved.', ['request_id' => $paymentRequest->id, 'user_id' => $user->id]);

        return response()->json(['message' => 'Payment approved successfully. User subscription is now active.']);
    }
}
