<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SaleCancelRequest;
use App\Http\Requests\Api\V1\SaleReturnRequest;
use App\Http\Resources\Api\V1\SaleReturnResource;
use App\Models\Sale;
use App\Services\SaleReturnService;
use Illuminate\Http\JsonResponse;

/** Owner only. Goods coming back, or a whole sale cancelled. */
class SaleReturnController extends Controller
{
    public function store(SaleReturnRequest $request, Sale $sale, SaleReturnService $returns): JsonResponse
    {
        $return = $returns->process($sale, $request->validated('items'), $request->boolean('restock', true), $request->validated('note'), $request->user()->id);

        return $this->answer($return, $sale);
    }

    public function cancel(SaleCancelRequest $request, Sale $sale, SaleReturnService $returns): JsonResponse
    {
        $return = $returns->process($sale, null, $request->boolean('restock', true), $request->validated('note'), $request->user()->id);

        return $this->answer($return, $sale);
    }

    private function answer($return, Sale $sale): JsonResponse
    {
        return (new SaleReturnResource($return))
            ->additional(['sale_balance' => $sale->refresh()->balance(), 'sale_cancelled' => $sale->cancelled_at !== null])
            ->response()
            ->setStatusCode(201);
    }
}
