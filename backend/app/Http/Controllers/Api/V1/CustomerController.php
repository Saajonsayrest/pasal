<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\CustomerRequest;
use App\Http\Resources\Api\V1\CustomerResource;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    /**
     * Query: search (name or phone), owes=1, paid_up=1, over_limit=1, sort=name|owed|oldest, per_page (max 50).
     * `summary` is for the whole business, not only this page: how much customers owe in total, and how many owe.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate(['sort' => ['nullable', 'in:name,owed,oldest']]);
        $owes = Customer::OWES_SQL;

        $customers = Customer::query()->withOwes()
            ->when($request->query('search'), function ($q, $term) {
                $like = '%'.addcslashes($term, '%_\\').'%';
                $q->where(fn ($w) => $w->where('name', 'ilike', $like)->orWhere('phone', 'ilike', $like));
            })
            ->when($request->boolean('owes'), fn ($q) => $q->whereRaw("$owes > 0"))
            ->when($request->boolean('paid_up'), fn ($q) => $q->whereRaw("$owes <= 0"))
            ->when($request->boolean('over_limit'), fn ($q) => $q->whereNotNull('credit_limit')->whereRaw("$owes > credit_limit"))
            ->when($request->query('sort') === 'owed', fn ($q) => $q->orderByRaw("$owes DESC")->orderBy('name'))
            ->when($request->query('sort') === 'oldest', fn ($q) => $q->orderByRaw('oldest_unpaid_at ASC NULLS LAST')->orderBy('name'))
            ->when(! in_array($request->query('sort'), ['owed', 'oldest'], true), fn ($q) => $q->orderBy('name'))
            ->paginate(min((int) $request->query('per_page', 50), 50));

        $totals = Customer::query()->selectRaw("COALESCE(SUM(GREATEST($owes, 0)), 0) AS owed_total, COUNT(*) FILTER (WHERE $owes > 0) AS owing")->first();

        return CustomerResource::collection($customers)->additional([
            'summary' => ['owed_total' => (int) $totals->owed_total, 'owing_customers' => (int) $totals->owing],
        ])->response();
    }

    public function store(CustomerRequest $request): JsonResponse
    {
        return (new CustomerResource(Customer::create($request->validated())))->response()->setStatusCode(201);
    }

    public function show(Customer $customer): CustomerResource
    {
        return new CustomerResource(Customer::withOwes()->findOrFail($customer->id));
    }

    public function update(CustomerRequest $request, Customer $customer): CustomerResource
    {
        $customer->update($request->validated());

        return new CustomerResource(Customer::withOwes()->findOrFail($customer->id));
    }

    public function destroy(Customer $customer): JsonResponse
    {
        $customer->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
