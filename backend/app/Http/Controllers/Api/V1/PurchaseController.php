<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PurchaseRequest;
use App\Http\Resources\Api\V1\PurchaseResource;
use App\Models\Purchase;
use App\Services\PurchaseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PurchaseController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $purchases = Purchase::with('supplier')
            ->when($request->boolean('unpaid'), fn ($q) => $q->whereColumn('paid', '<', 'total'))
            ->when($request->query('supplier_id'), fn ($q, $id) => $q->where('supplier_id', $id))
            ->latest('bought_at')
            ->paginate(min((int) $request->query('per_page', 20), 50));

        return PurchaseResource::collection($purchases);
    }

    public function store(PurchaseRequest $request, PurchaseService $purchases): JsonResponse
    {
        $purchase = $purchases->create($request->validated(), $request->user()->id);

        return (new PurchaseResource($purchase))->response()->setStatusCode(201);
    }

    public function show(Purchase $purchase): PurchaseResource
    {
        return new PurchaseResource($purchase->load('items.item', 'supplier', 'payments'));
    }
}
