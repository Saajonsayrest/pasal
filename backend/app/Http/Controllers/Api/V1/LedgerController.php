<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\CustomerResource;
use App\Http\Resources\Api\V1\SupplierResource;
use App\Models\Customer;
use App\Models\Purchase;
use App\Models\Sale;
use App\Models\Supplier;
use Illuminate\Http\JsonResponse;

class LedgerController extends Controller
{
    /** What this customer still owes us (udhar), with every sale. */
    public function customer(Customer $customer): JsonResponse
    {
        $sales = Sale::where('customer_id', $customer->id)->latest('sold_at')->limit(200)->get();

        return response()->json([
            'customer' => (new CustomerResource($customer))->resolve(),
            'total_sales' => (int) Sale::where('customer_id', $customer->id)->sum('total'),
            'total_paid' => (int) Sale::where('customer_id', $customer->id)->sum('paid'),
            'owes' => (int) Sale::where('customer_id', $customer->id)->selectRaw('COALESCE(SUM(total - paid), 0) AS owes')->value('owes'),
            'sales' => $sales->map(fn ($s) => [
                'id' => $s->id, 'sold_at' => $s->sold_at, 'total' => $s->total, 'paid' => $s->paid, 'balance' => $s->total - $s->paid,
            ]),
        ]);
    }

    /** What we still owe this supplier, with every purchase. */
    public function supplier(Supplier $supplier): JsonResponse
    {
        $purchases = Purchase::where('supplier_id', $supplier->id)->latest('bought_at')->limit(200)->get();

        return response()->json([
            'supplier' => (new SupplierResource($supplier))->resolve(),
            'total_purchases' => (int) Purchase::where('supplier_id', $supplier->id)->sum('total'),
            'total_paid' => (int) Purchase::where('supplier_id', $supplier->id)->sum('paid'),
            'we_owe' => (int) Purchase::where('supplier_id', $supplier->id)->selectRaw('COALESCE(SUM(total - paid), 0) AS owes')->value('owes'),
            'purchases' => $purchases->map(fn ($p) => [
                'id' => $p->id, 'bought_at' => $p->bought_at, 'total' => $p->total, 'paid' => $p->paid, 'balance' => $p->total - $p->paid,
            ]),
        ]);
    }
}
