<?php

// app/Http/Controllers/MaintenanceController.php

namespace App\Http\Controllers;

use App\Models\MaintenanceSetting;
use Illuminate\Http\Request;

class MaintenanceController extends Controller
{
    public function index()
    {
        $setting = MaintenanceSetting::first();
        return response()->json(['isMaintenance' => $setting ? $setting->isMaintenance : false]);
    }

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
