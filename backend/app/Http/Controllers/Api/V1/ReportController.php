<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ReportRequest;
use App\Models\Expense;
use App\Models\Item;
use App\Models\Purchase;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use Illuminate\Http\JsonResponse;

class ReportController extends Controller
{
    public function summary(ReportRequest $request): JsonResponse
    {
        $from = $request->date('from')->startOfDay();
        $to = $request->date('to')->endOfDay();

        // Returns count on the day they happened, and take their sales, VAT and cost back out.
        $range = Sale::whereBetween('sold_at', [$from, $to]);
        $returned = SaleReturn::whereBetween('returned_at', [$from, $to]);
        $sales = (int) (clone $range)->sum('total') - (int) (clone $returned)->sum('total');
        $vatCollected = (int) (clone $range)->sum('vat_amount') - (int) (clone $returned)->sum('vat_amount'); // belongs to IRD, not profit
        $cost = (int) SaleItem::whereHas('sale', fn ($q) => $q->whereBetween('sold_at', [$from, $to]))
            ->selectRaw('COALESCE(SUM(quantity * unit_cost), 0) AS cost')->value('cost')
            - (int) (clone $returned)->where('restocked', true)->sum('cost'); // goods put back on the shelf cost nothing
        $expenses = (int) Expense::whereBetween('spent_at', [$from, $to])->sum('amount');

        return response()->json([
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'sales_total' => $sales,
            'vat_collected' => $vatCollected,
            'cost_of_goods' => $cost,
            'expenses_total' => $expenses,
            'profit' => $sales - $vatCollected - $cost - $expenses,
            // These two are as of today, not limited to the date range.
            'stock_value' => (int) Item::selectRaw('COALESCE(SUM(quantity * cost_price), 0) AS v')->value('v'),
            'owed_to_us' => (int) Sale::selectRaw('COALESCE(SUM(total - returned_total - paid), 0) AS v')->value('v'),
            'we_owe' => (int) Purchase::selectRaw('COALESCE(SUM(total - paid), 0) AS v')->value('v'),
        ]);
    }
}
