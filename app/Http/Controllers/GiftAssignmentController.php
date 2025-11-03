<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\GiftPurchase;
use App\Models\AssignedGift;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class GiftAssignmentController extends Controller
{
    // For React admin to assign a gift from a pool to a user
    public function assign(Request $request)
    {
        $validator = \Validator::make($request->all(), [
            'recipient_user_id' => 'required|integer|exists:users,id',
            'gift_purchase_id' => 'required|integer|exists:gift_purchases,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $purchase = GiftPurchase::find($request->gift_purchase_id);
        $recipient = User::find($request->recipient_user_id);

        // --- Business Logic Checks ---
        if ($purchase->status !== 'approved' || $purchase->quantity_remaining <= 0) {
            return response()->json(['message' => 'This gift pool is not active or has no gifts remaining.'], 400);
        }

        // --- The Core Logic ---
        
        // 1. Update the recipient's subscription
        $startDate = $recipient->subscription_expires_at && $recipient->subscription_expires_at->isFuture()
            ? $recipient->subscription_expires_at
            : Carbon::now();

        if ($purchase->plan_duration === 'yearly') {
            $recipient->subscription_expires_at = $startDate->addYear();
        } else { // 'six_month'
            $recipient->subscription_expires_at = $startDate->addMonths(6);
        }
        $recipient->is_subscribed = true;
        $recipient->save();

        // 2. Decrement the gift pool
        $purchase->quantity_remaining -= 1;
        $purchase->save();

        // 3. Log the assignment
        AssignedGift::create([
            'gift_purchase_id' => $purchase->id,
            'recipient_user_id' => $recipient->id,
            'assigned_by_admin_id' => Auth::id(),
        ]);

        Log::info('Gift assigned from pool.', [
            'purchase_id' => $purchase->id,
            'recipient_id' => $recipient->id,
            'admin_id' => Auth::id()
        ]);
        
        return response()->json(['message' => 'Gift assigned successfully. The user is now subscribed.']);
    }
}