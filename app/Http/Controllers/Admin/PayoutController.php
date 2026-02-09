<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Payout;
use App\Models\RevenueTransaction;
use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;

class PayoutController extends Controller
{
    public function index(Request $request)
    {
            /**
             * @OA\Get(
             *     path="/admin/payouts",
             *     summary="Get list of payouts",
             *     tags={"Payout"},
             *     @OA\Parameter(
             *         name="status",
             *         in="query",
             *         required=false,
             *         description="Filter by payout status",
             *         @OA\Schema(type="string")
             *     ),
             *     @OA\Parameter(
             *         name="start_date",
             *         in="query",
             *         required=false,
             *         description="Start date for filtering",
             *         @OA\Schema(type="string", format="date")
             *     ),
             *     @OA\Parameter(
             *         name="end_date",
             *         in="query",
             *         required=false,
             *         description="End date for filtering",
             *         @OA\Schema(type="string", format="date")
             *     ),
             *     @OA\Response(response=200, description="List of payouts returned")
             * )
             */
        $query = Payout::with(['requester:id,name', 'reviewer:id,name']);

        // Filtering logic
        if ($request->has('status') && $request->status !== 'all') {
            $query->where('status', $request->status);
        }
        if ($request->has('start_date') && $request->has('end_date')) {
            $startDate = Carbon::parse($request->start_date)->startOfDay();
            $endDate = Carbon::parse($request->end_date)->endOfDay();
            $query->whereBetween('requested_at', [$startDate, $endDate]);
        }

        $payouts = $query->latest('requested_at')->get();

        return response()->json($payouts);
    }

    public function store(Request $request)
    {
            /**
             * @OA\Post(
             *     path="/admin/payouts",
             *     summary="Create a payout request",
             *     tags={"Payout"},
             *     @OA\RequestBody(
             *         required=true,
             *         @OA\JsonContent(
             *             required={"amount"},
             *             @OA\Property(property="amount", type="number", format="float")
             *         )
             *     ),
             *     @OA\Response(response=201, description="Payout request submitted successfully"),
             *     @OA\Response(response=403, description="Unauthorized"),
             *     @OA\Response(response=422, description="Payout amount exceeds available balance")
             * )
             */
        // Security: Hardcoded check for Basirah admin
        if (Auth::user()->email !== 'basirah@gmail.com') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $request->validate(['amount' => 'required|numeric|min:1']);

        // Security: Recalculate balance on the server to prevent manipulation
        $totalRevenue = RevenueTransaction::sum('amount');
        $totalPayouts = Payout::where('status', 'approved')->sum('amount_paid');
        $skylinkBalance = ($totalRevenue * 0.30) - $totalPayouts;

        if ($request->amount > $skylinkBalance) {
            return response()->json(['message' => 'Payout amount exceeds available balance.'], 422);
        }

        $payout = Payout::create([
            'amount_paid' => $request->amount,
            'requested_by_admin_id' => Auth::id(),
            'requested_at' => Carbon::now(),
            'status' => 'pending',
        ]);

        return response()->json(['message' => 'Payout request submitted successfully.', 'payout' => $payout], 201);
    }

    public function updateStatus(Request $request, Payout $payout)
    {
            /**
             * @OA\Put(
             *     path="/admin/payouts/{payout}",
             *     summary="Update payout status",
             *     tags={"Payout"},
             *     @OA\Parameter(
             *         name="payout",
             *         in="path",
             *         required=true,
             *         description="Payout ID",
             *         @OA\Schema(type="integer")
             *     ),
             *     @OA\RequestBody(
             *         required=true,
             *         @OA\JsonContent(
             *             required={"status"},
             *             @OA\Property(property="status", type="string", enum={"approved","declined"})
             *         )
             *     ),
             *     @OA\Response(response=200, description="Payout status updated successfully"),
             *     @OA\Response(response=403, description="Unauthorized"),
             *     @OA\Response(response=409, description="This payout has already been processed")
             * )
             */
        // Security: Hardcoded check for Skylink admin
        if (Auth::user()->email !== 'skylink@gmail.com') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $request->validate(['status' => 'required|in:approved,declined']);

        if ($payout->status !== 'pending') {
            return response()->json(['message' => 'This payout has already been processed.'], 409);
        }

        $payout->update([
            'status' => $request->status,
            'reviewed_by_admin_id' => Auth::id(),
            'reviewed_at' => Carbon::now(),
        ]);

        return response()->json(['message' => 'Payout status updated successfully.', 'payout' => $payout]);
    }
}
