<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\GiftPurchase;
use App\Models\RevenueTransaction; // <-- ADD THIS IMPORT
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon; // <-- ADD THIS IMPORT

class GiftPurchaseController extends Controller
{
    // For Flutter app to submit a purchase
        /**
         * @OA\Post(
         *     path="/gift-purchases",
         *     summary="Submit a gift purchase",
         *     tags={"GiftPurchase"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"plan_duration","quantity","total_price","transaction_id"},
         *             @OA\Property(property="plan_duration", type="string", enum={"six_month","yearly"}),
         *             @OA\Property(property="quantity", type="integer"),
         *             @OA\Property(property="total_price", type="number", format="float"),
         *             @OA\Property(property="transaction_id", type="string")
         *         )
         *     ),
         *     @OA\Response(response=201, description="Your gift purchase has been submitted for review."),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */
    public function store(Request $request)
    {
        $validator = \Validator::make($request->all(), [
            'plan_duration' => 'required|string|in:six_month,yearly',
            'quantity' => 'required|integer|min:1',
            'total_price' => 'required|numeric|min:0',
            'transaction_id' => 'required|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        GiftPurchase::create([
            'gifter_user_id' => Auth::id(),
            'plan_duration' => $request->plan_duration,
            'quantity_purchased' => $request->quantity,
            'total_price' => $request->total_price,
            'transaction_id' => $request->transaction_id,
            'status' => 'pending',
        ]);

        return response()->json(['message' => 'Your gift purchase has been submitted for review.'], 201);
    }

    // For React admin to list all gift purchases
        /**
         * @OA\Get(
         *     path="/gift-purchases",
         *     summary="List all gift purchases",
         *     tags={"GiftPurchase"},
         *     @OA\Response(response=200, description="List of gift purchases")
         * )
         */
    public function index()
    {
        $purchases = GiftPurchase::with('gifter:id,first_name,last_name')
                            ->orderBy('status', 'desc')
                            ->latest()
                            ->get();
        return response()->json($purchases);
    }

    // For React admin to approve the payment
        /**
         * @OA\Patch(
         *     path="/gift-purchases/{giftPurchase}/approve-payment",
         *     summary="Approve payment for a gift purchase",
         *     tags={"GiftPurchase"},
         *     @OA\Parameter(
         *         name="giftPurchase",
         *         in="path",
         *         required=true,
         *         description="Gift Purchase ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="Payment approved. The gift pool is now active."),
         *     @OA\Response(response=409, description="This purchase has already been processed.")
         * )
         */
    public function approvePayment(GiftPurchase $giftPurchase)
    {
        if ($giftPurchase->status !== 'pending') {
            return response()->json(['message' => 'This purchase has already been processed.'], 409);
        }

        $giftPurchase->status = 'approved';
        $giftPurchase->quantity_remaining = $giftPurchase->quantity_purchased;
        $giftPurchase->save();

        // ** NEW: Create a permanent revenue transaction record **
        // We log the entire purchase amount at the time of approval.
        RevenueTransaction::create([
            'source_type'  => 'GiftPurchase',
            'source_id'    => $giftPurchase->id,
            'amount'       => $giftPurchase->total_price,
            'plan_duration'=> $giftPurchase->plan_duration, // We log the plan type of the gift pool
            'processed_at' => Carbon::now(),
        ]);
        // --- END OF NEW CODE ---

        Log::info('Gift payment approved.', ['purchase_id' => $giftPurchase->id]);
        return response()->json(['message' => 'Payment approved. The gift pool is now active.']);
    }
}
