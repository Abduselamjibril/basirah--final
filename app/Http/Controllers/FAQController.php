<?php

namespace App\Http\Controllers;

use App\Models\FAQ;
use Illuminate\Http\Request;

class FAQController extends Controller
{
    public function index()
        /**
         * @OA\Get(
         *     path="/faqs",
         *     summary="Get all FAQs",
         *     tags={"FAQ"},
         *     @OA\Response(response=200, description="List of FAQs")
         * )
         */
    {
        return FAQ::all();
    }

    public function store(Request $request)
        /**
         * @OA\Post(
         *     path="/faqs",
         *     summary="Create a new FAQ",
         *     tags={"FAQ"},
         *     @OA\RequestBody(
         *         required=true,
         *         @OA\JsonContent(
         *             required={"question","answer"},
         *             @OA\Property(property="question", type="string"),
         *             @OA\Property(property="answer", type="string")
         *         )
         *     ),
         *     @OA\Response(response=201, description="FAQ created successfully."),
         *     @OA\Response(response=422, description="Validation error")
         * )
         */
    {
        $validated = $request->validate([
            'question' => 'required|string',
            'answer' => 'required|string',
        ]);

        $faq = FAQ::create($validated);
        return response()->json($faq, 201);
    }

    public function show($id)
        /**
         * @OA\Get(
         *     path="/faqs/{id}",
         *     summary="Get a single FAQ by ID",
         *     tags={"FAQ"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="FAQ ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=200, description="FAQ found"),
         *     @OA\Response(response=404, description="FAQ not found.")
         * )
         */
    {
        return FAQ::findOrFail($id);
    }

    public function update(Request $request, $id)
        /**
         * @OA\Put(
         *     path="/faqs/{id}",
         *     summary="Update a FAQ",
         *     tags={"FAQ"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="FAQ ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\RequestBody(
         *         required=false,
         *         @OA\JsonContent(
         *             @OA\Property(property="question", type="string"),
         *             @OA\Property(property="answer", type="string")
         *         )
         *     ),
         *     @OA\Response(response=200, description="FAQ updated successfully."),
         *     @OA\Response(response=404, description="FAQ not found.")
         * )
         */
    {
        $faq = FAQ::findOrFail($id);
        $faq->update($request->only(['question', 'answer']));
        return response()->json($faq, 200);
    }

    public function destroy($id)
        /**
         * @OA\Delete(
         *     path="/faqs/{id}",
         *     summary="Delete a FAQ",
         *     tags={"FAQ"},
         *     @OA\Parameter(
         *         name="id",
         *         in="path",
         *         required=true,
         *         description="FAQ ID",
         *         @OA\Schema(type="integer")
         *     ),
         *     @OA\Response(response=204, description="FAQ deleted successfully."),
         *     @OA\Response(response=404, description="FAQ not found.")
         * )
         */
    {
        FAQ::destroy($id);
        return response()->json(null, 204);
    }
}
