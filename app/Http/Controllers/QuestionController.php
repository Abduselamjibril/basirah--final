<?php

namespace App\Http\Controllers;

use App\Models\Question;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class QuestionController extends Controller
{
    /**
     * Display a listing of questions for the admin panel.
     */
    public function index()
    {
        // Load questions with the user who asked them
        return Question::with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc')
            ->get();
    }

    /**
     * Store a newly created question from the mobile app.
     */
    public function store(Request $request)
    {
        $request->validate([
            'question_text' => 'required|string',
        ]);

        $question = Question::create([
            'user_id' => Auth::id(),
            'question_text' => $request->question_text,
        ]);

        return response()->json([
            'message' => 'Question submitted successfully.',
            'question' => $question
        ], 201);
    }

    /**
     * Remove the specified question from storage.
     */
    public function destroy($id)
    {
        $question = Question::findOrFail($id);
        $question->delete();

        return response()->json([
            'message' => 'Question deleted successfully.'
        ]);
    }
}
