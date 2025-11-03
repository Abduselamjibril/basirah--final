<?php

namespace App\Http\Controllers;

use App\Models\FAQ;
use Illuminate\Http\Request;

class FAQController extends Controller
{
    public function index()
    {
        return FAQ::all();
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'question' => 'required|string',
            'answer' => 'required|string',
        ]);

        $faq = FAQ::create($validated);
        return response()->json($faq, 201);
    }

    public function show($id)
    {
        return FAQ::findOrFail($id);
    }

    public function update(Request $request, $id)
    {
        $faq = FAQ::findOrFail($id);
        $faq->update($request->only(['question', 'answer']));
        return response()->json($faq, 200);
    }

    public function destroy($id)
    {
        FAQ::destroy($id);
        return response()->json(null, 204);
    }
}
