<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ExpenseRequest;
use App\Http\Resources\Api\V1\ExpenseResource;
use App\Models\Expense;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ExpenseController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return ExpenseResource::collection(
            Expense::latest('spent_at')->paginate(min((int) $request->query('per_page', 20), 50))
        );
    }

    public function store(ExpenseRequest $request): JsonResponse
    {
        $expense = Expense::create([
            ...$request->validated(),
            'spent_at' => $request->validated('spent_at') ?? now(),
            'user_id' => $request->user()->id,
        ]);

        return (new ExpenseResource($expense))->response()->setStatusCode(201);
    }
}
