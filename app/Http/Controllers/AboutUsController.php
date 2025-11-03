<?php

namespace App\Http\Controllers;

use App\Models\AboutUs;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AboutUsController extends Controller
{
    // Public method for Flutter App
    public function get()
    {
        $content = AboutUs::firstOrCreate(
            ['id' => 1],
            ['title' => 'About Us', 'content' => 'Welcome! Content is being updated.']
        );
        return response()->json($content);
    }

    // Admin method to update content
    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'content' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $content = AboutUs::updateOrCreate(
            ['id' => 1],
            $request->only(['title', 'content'])
        );

        return response()->json(['message' => 'About Us page updated successfully.', 'data' => $content]);
    }
}