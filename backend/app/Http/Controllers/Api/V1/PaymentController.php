<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PaymentRequest;
use App\Http\Resources\Api\V1\PaymentResource;
use App\Models\Customer;
use App\Models\Payment;
use App\Models\Purchase;
use App\Models\Sale;
use App\Models\Supplier;
use App\Services\PaymentService;
use App\Support\ShopDay;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PaymentController extends Controller
{
    /** Owner: every payment of the shop, newest first. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'direction' => ['nullable', 'in:in,out,refund'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
            'method' => ['nullable', 'string', 'max:20'],
            'sale_id' => ['nullable', 'integer'],
            'purchase_id' => ['nullable', 'integer'],
            'customer_id' => ['nullable', 'integer'],
            'supplier_id' => ['nullable', 'integer'],
        ]);

        $payments = Payment::with('sale.customer', 'purchase.supplier')
            ->when($request->query('direction'), fn ($q, $v) => $q->where('direction', $v))
            ->when($request->query('method'), fn ($q, $v) => $q->where('method', $v))
            ->when($request->query('from'), fn ($q, $v) => $q->where('paid_at', '>=', ShopDay::start($request->date('from')->toDateString())))
            ->when($request->query('to'), fn ($q, $v) => $q->where('paid_at', '<=', ShopDay::end($request->date('to')->toDateString())))
            ->when($request->query('sale_id'), fn ($q, $v) => $q->where('sale_id', $v))
            ->when($request->query('purchase_id'), fn ($q, $v) => $q->where('purchase_id', $v))
            ->when($request->query('customer_id'), fn ($q, $v) => $q->whereHas('sale', fn ($s) => $s->where('customer_id', $v)))
            ->when($request->query('supplier_id'), fn ($q, $v) => $q->whereHas('purchase', fn ($s) => $s->where('supplier_id', $v)))
            ->orderByDesc('paid_at')->orderByDesc('id')
            ->paginate(min((int) $request->query('per_page', 30), 100));

        return PaymentResource::collection($payments);
    }

    public function store(PaymentRequest $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validated();

        if (isset($data['customer_id']) || isset($data['supplier_id'])) {
            $party = isset($data['customer_id']) ? Customer::findOrFail($data['customer_id']) : Supplier::findOrFail($data['supplier_id']);
            $result = $payments->allocate($party, $data['amount'], $request->user()->id, $data['method'] ?? null, $data['paid_at'] ?? null);

            return PaymentResource::collection($result['payments'])
                ->additional(['owes_left' => $result['owes_left']])
                ->response()
                ->setStatusCode(201);
        }

        $target = isset($data['sale_id']) ? Sale::findOrFail($data['sale_id']) : Purchase::findOrFail($data['purchase_id']);

        $payment = $payments->record($target, $data['amount'], $request->user()->id, $data['method'] ?? null, $data['paid_at'] ?? null);

        return (new PaymentResource($payment))
            ->additional(['balance_left' => $target instanceof Sale ? $target->balance() : $target->total - $target->paid])
            ->response()
            ->setStatusCode(201);
    }
}
