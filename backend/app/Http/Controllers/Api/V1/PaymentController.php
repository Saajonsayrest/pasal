<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PaymentRequest;
use App\Http\Resources\Api\V1\PaymentResource;
use App\Models\Purchase;
use App\Models\Sale;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;

class PaymentController extends Controller
{
    public function store(PaymentRequest $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validated();
        $target = isset($data['sale_id']) ? Sale::findOrFail($data['sale_id']) : Purchase::findOrFail($data['purchase_id']);

        $payment = $payments->record($target, $data['amount'], $request->user()->id, $data['method'] ?? null, $data['paid_at'] ?? null);

        return (new PaymentResource($payment))
            ->additional(['balance_left' => $target->total - $target->paid])
            ->response()
            ->setStatusCode(201);
    }
}
