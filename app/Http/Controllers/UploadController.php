<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
        /**
         * @OA\Post(
         *     path="/upload",
         *     summary="Upload a file (audio/video)",
         *     tags={"Upload"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"file"},
         *             @OA\Property(property="file", type="string", format="binary")
         *         )
         *     ),
         *     @OA\Response(response=200, description="File uploaded successfully. Returns file path."),
         *     @OA\Response(response=422, description="Validation error.")
         * )
         */
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
