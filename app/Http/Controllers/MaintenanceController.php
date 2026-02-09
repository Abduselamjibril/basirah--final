<?php

// app/Http/Controllers/MaintenanceController.php

namespace App\Http\Controllers;

use App\Models\MaintenanceSetting;
use Illuminate\Http\Request;

class MaintenanceController extends Controller
{
        /**
         * @OA\Get(
         *     path="/maintenance",
         *     summary="Get maintenance mode status",
         *     tags={"Maintenance"},
         *     @OA\Response(response=200, description="Maintenance mode status returned")
         * )
         */
    public function index()
    {
        $setting = MaintenanceSetting::first();
        return response()->json(['isMaintenance' => $setting ? $setting->isMaintenance : false]);
    }

        /**
         * @OA\Put(
         *     path="/maintenance",
         *     summary="Update maintenance mode status",
         *     tags={"Maintenance"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"isMaintenance"},
         *             @OA\Property(property="isMaintenance", type="boolean")
         *         )
         *     ),
         *     @OA\Response(response=200, description="Maintenance mode status updated")
         * )
         */
    public function update(Request $request)
    {
        $request->validate([
            'isMaintenance' => 'required|boolean',
        ]);

        $setting = MaintenanceSetting::first() ?? new MaintenanceSetting();
        $setting->isMaintenance = $request->isMaintenance;
        $setting->save();

        return response()->json(['isMaintenance' => $setting->isMaintenance]);
    }
}
