<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\RevenueTransaction;
use App\Models\Payout;
use App\Models\User;
use Carbon\Carbon;

class FinancialReportController extends Controller
{
    public function getReport(Request $request)
    {
            /**
             * @OA\Get(
             *     path="/admin/financial-report",
             *     summary="Get financial report summary",
             *     tags={"FinancialReport"},
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
             *     @OA\Response(response=200, description="Financial report returned")
             * )
             */
        $startDate = $request->start_date ? Carbon::parse($request->start_date)->startOfDay() : null;
        $endDate = $request->end_date ? Carbon::parse($request->end_date)->endOfDay() : null;

        // Base query for revenue
        $revenueQuery = RevenueTransaction::query();
        if ($startDate && $endDate) {
            $revenueQuery->whereBetween('processed_at', [$startDate, $endDate]);
        }

        // --- CALCULATIONS ---
        $totalRevenue = $revenueQuery->sum('amount');
        $totalPayouts = Payout::where('status', 'approved')->sum('amount_paid');

        $skylinkShareTotal = $totalRevenue * 0.30;
        $skylinkBalance = $skylinkShareTotal - $totalPayouts;

        // Clone the query to get plan counts
        $planCountsQuery = clone $revenueQuery;
        $sixMonthCount = $planCountsQuery->where('plan_duration', 'six_month')->count();
        $yearlyCount = $revenueQuery->where('plan_duration', 'yearly')->count(); // Use original query for yearly

        // Total Subscribed Users (this is system-wide, not date-filtered)
        $totalSubscribedUsers = User::where('is_subscribed', true)
                                    ->where('subscription_expires_at', '>', Carbon::now())
                                    ->count();

        return response()->json([
            'total_revenue' => $totalRevenue,
            'share_distribution' => [
                'basirah_70_percent' => $totalRevenue * 0.70,
                'skylink_30_percent' => $skylinkShareTotal,
            ],
            'skylink_payout_summary' => [
                'total_share_earned' => $skylinkShareTotal,
                'total_paid_out' => $totalPayouts,
                'balance_available_for_payout' => $skylinkBalance,
            ],
            'subscription_counts' => [
                'total_active_subscribers' => $totalSubscribedUsers,
                'six_month_plans_sold' => $sixMonthCount,
                'yearly_plans_sold' => $yearlyCount,
            ],
        ]);
    }

    // Placeholder for future export functionality
    public function export(Request $request)
    {
            /**
             * @OA\Get(
             *     path="/admin/financial-report/export",
             *     summary="Export financial report",
             *     tags={"FinancialReport"},
             *     @OA\Response(response=200, description="Export not implemented")
             * )
             */
        // Logic for generating Excel/Doc will go here using a package like Maatwebsite/Excel.
        return response()->json(['message' => 'Export functionality not yet implemented.']);
    }
}
