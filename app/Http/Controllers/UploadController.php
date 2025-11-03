<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
    public function uploadFile(Request $request)
    {
        // Validate the uploaded file
        $request->validate([
            'file' => 'required|file|mimes:mp3,wav,mp4,avi,m4v|max:20480', // Max 20MB
        ]);

        // Store the file
        $path = $request->file('file')->store('uploads');

        // Return the path to the uploaded file
        return response()->json(['path' => $path], 200);
    }
}