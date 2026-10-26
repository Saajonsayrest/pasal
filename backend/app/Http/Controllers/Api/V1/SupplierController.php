<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SupplierRequest;
use App\Http\Resources\Api\V1\SupplierResource;
use App\Models\Supplier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    /**
     * Query: search (name or phone), owed=1 (we owe them), per_page (max 50).
     * `summary.owed_total` is what the business owes all suppliers, not only this page.
     */
    public function index(Request $request): JsonResponse
    {
        $owed = Supplier::WE_OWE_SQL;

        $suppliers = Supplier::query()->withOwed()
            ->when($request->query('search'), function ($q, $term) {
                $like = '%'.addcslashes($term, '%_\\').'%';
                $q->where(fn ($w) => $w->where('name', 'ilike', $like)->orWhere('phone', 'ilike', $like));
            })
            ->when($request->boolean('owed'), fn ($q) => $q->whereRaw("$owed > 0"))
            ->orderBy('name')
            ->paginate(min((int) $request->query('per_page', 50), 50));

        $total = Supplier::query()->selectRaw("COALESCE(SUM(GREATEST($owed, 0)), 0) AS owed_total")->value('owed_total');

        return SupplierResource::collection($suppliers)->additional(['summary' => ['owed_total' => (int) $total]])->response();
    }

    public function store(SupplierRequest $request): JsonResponse
    {
        $supplier = Supplier::create($request->validated());

        return (new SupplierResource($supplier))->response()->setStatusCode(201);
    }

    public function show(Supplier $supplier): SupplierResource
    {
        return new SupplierResource(Supplier::withOwed()->findOrFail($supplier->id));
    }

    public function update(SupplierRequest $request, Supplier $supplier): SupplierResource
    {
        $supplier->update($request->validated());

        return new SupplierResource(Supplier::withOwed()->findOrFail($supplier->id));
    }

    public function destroy(Supplier $supplier): JsonResponse
    {
        $supplier->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
