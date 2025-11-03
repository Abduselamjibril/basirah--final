<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Course;
use App\Models\Surah;
use App\Models\Story;
use App\Models\Commentary;
use App\Models\DeeperLook;

class DashboardController extends Controller
{
    /**
     * Fetch aggregate statistics for the admin dashboard.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function getStats()
    {
        $stats = [
            'users' => User::count(),
            'courses' => Course::count(),
            'surahs' => Surah::count(),
            'stories' => Story::count(),
            'commentaries' => Commentary::count(),
            'deeperLooks' => DeeperLook::count(),
        ];

        return response()->json($stats);
    }
}
