<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SaleRequest;
use App\Http\Resources\Api\V1\SaleResource;
use App\Models\Sale;
use App\Services\SaleService;
use App\Support\ShopDay;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class SaleController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate(['from' => ['nullable', 'date'], 'to' => ['nullable', 'date', 'after_or_equal:from']]);

        $sales = Sale::with('customer', 'user:id,name')
            ->when($request->boolean('unpaid'), fn ($q) => $q->whereRaw('paid < total - returned_total'))
            ->when($request->query('customer_id'), fn ($q, $id) => $q->where('customer_id', $id))
            // Nepal days, both included (the shop's day, UTC+5:45).
            ->when($request->query('from'), fn ($q, $d) => $q->where('sold_at', '>=', ShopDay::start($d)))
            ->when($request->query('to'), fn ($q, $d) => $q->where('sold_at', '<=', ShopDay::end($d)))
            ->when($request->query('search'), function ($q, $term) {
                $like = '%'.addcslashes($term, '%_\\').'%';
                $q->where(fn ($w) => $w->where('bill_no', 'ilike', $like)
                    ->orWhereHas('customer', fn ($c) => $c->where('name', 'ilike', $like)));
            })
            ->latest('sold_at')
            ->paginate(min((int) $request->query('per_page', 20), 50));

        return SaleResource::collection($sales);
    }

    public function store(SaleRequest $request, SaleService $sales): JsonResponse
    {
        $discountCap = $request->user()->isOwner() ? null : (int) config('pasal.staff_max_discount_percent');
        $sale = $sales->create($request->validated(), $request->user()->id, $discountCap);

        return (new SaleResource($sale))->response()->setStatusCode(201);
    }

    public function show(Sale $sale): SaleResource
    {
        return new SaleResource($sale->load('items.item', 'customer', 'user:id,name', 'payments', 'returns.items'));
    }
}
