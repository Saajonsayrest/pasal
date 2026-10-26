<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ReportRequest;
use App\Models\Item;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Owner only. Report details for the Reports screens: sales per day and hour, top and slow items,
 * how old the customer credit is, and sales per staff member.
 *
 * Days and hours are shop time (Nepal, UTC+5:45), because a shop thinks in its own days.
 * `from` and `to` are Nepal calendar dates, both days included.
 */
class ReportDetailController extends Controller
{
    private const ZONE = 'Asia/Kathmandu';

    /** The same moment as the stored UTC timestamp, written in shop time. */
    private function local(string $column): string
    {
        return "((({$column}) AT TIME ZONE 'UTC') AT TIME ZONE '".self::ZONE."')";
    }

    /** @return array{0: Carbon, 1: Carbon} UTC start and end of the Nepal days */
    private function range(Request $request): array
    {
        $from = Carbon::parse($request->input('from'), self::ZONE)->startOfDay();
        $to = Carbon::parse($request->input('to'), self::ZONE)->endOfDay();
        abort_if($from->diffInDays($to) > 400, 422, 'Pick a range of at most 400 days.');

        return [$from->utc(), $to->utc()];
    }

    /** Sales per day and per hour of the day. Returns are taken off on the day they happened. */
    public function daily(ReportRequest $request): JsonResponse
    {
        [$from, $to] = $this->range($request);

        $sales = Sale::whereBetween('sold_at', [$from, $to])
            ->selectRaw($this->local('sold_at').'::date AS d, EXTRACT(HOUR FROM '.$this->local('sold_at').')::int AS h, COUNT(*) AS bills, COALESCE(SUM(total), 0) AS amount')
            ->groupByRaw('1, 2')->get();
        $returns = SaleReturn::whereBetween('returned_at', [$from, $to])
            ->selectRaw($this->local('returned_at').'::date AS d, COALESCE(SUM(total), 0) AS amount')
            ->groupByRaw('1')->pluck('amount', 'd');

        $days = [];
        for ($day = $from->copy()->setTimezone(self::ZONE)->startOfDay(); $day->lte($to->copy()->setTimezone(self::ZONE)); $day->addDay()) {
            $days[$day->toDateString()] = ['date' => $day->toDateString(), 'bills' => 0, 'sales' => 0];
        }
        $hours = array_map(fn ($h) => ['hour' => $h, 'bills' => 0, 'sales' => 0], range(0, 23));

        foreach ($sales as $row) {
            $days[$row->d]['bills'] += (int) $row->bills;
            $days[$row->d]['sales'] += (int) $row->amount;
            $hours[$row->h]['bills'] += (int) $row->bills;
            $hours[$row->h]['sales'] += (int) $row->amount;
        }
        foreach ($returns as $date => $amount) {
            if (isset($days[$date])) {
                $days[$date]['sales'] -= (int) $amount;
            }
        }

        return response()->json([
            'from' => $request->input('from'),
            'to' => $request->input('to'),
            'days' => array_values($days),
            'hours' => $hours,
            'total' => array_sum(array_column($days, 'sales')),
            'bills' => array_sum(array_column($days, 'bills')),
        ]);
    }

    /** Best sellers, and items that sit on the shelf without selling. Quantities are after returns. */
    public function items(Request $request): JsonResponse
    {
        $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        [$from, $to] = $this->range($request);
        $limit = (int) $request->query('limit', 10);

        $sold = SaleItem::query()
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->whereBetween('sales.sold_at', [$from, $to])
            ->groupBy('sale_items.item_id')
            ->selectRaw('sale_items.item_id AS item_id, SUM(sale_items.quantity - sale_items.returned_quantity) AS qty, SUM(sale_items.quantity * sale_items.unit_price - sale_items.discount - sale_items.returned_amount) AS revenue')
            ->get()->keyBy('item_id');

        $names = Item::withTrashed()->whereIn('id', $sold->keys())->get(['id', 'name', 'unit'])->keyBy('id');

        $top = $sold->filter(fn ($r) => $r->qty > 0)->sortByDesc('qty')->take($limit)->map(fn ($r) => [
            'item_id' => (int) $r->item_id,
            'name' => $names[$r->item_id]->name ?? '?',
            'unit' => $names[$r->item_id]->unit ?? 'pcs',
            'quantity' => (int) $r->qty,
            'revenue' => (int) $r->revenue,
        ])->values();

        // Slow: in stock, but sold least in the range. The most stock sitting still comes first.
        $slow = Item::where('quantity', '>', 0)->get(['id', 'name', 'unit', 'quantity', 'cost_price'])
            ->map(fn ($i) => [
                'item_id' => $i->id,
                'name' => $i->name,
                'unit' => $i->unit,
                'in_stock' => $i->quantity,
                'sold' => (int) ($sold[$i->id]->qty ?? 0),
                'stock_value' => $i->quantity * $i->cost_price,
            ])
            ->sortBy([['sold', 'asc'], ['stock_value', 'desc']])->take($limit)->values();

        return response()->json(['from' => $request->input('from'), 'to' => $request->input('to'), 'top' => $top, 'slow' => $slow]);
    }

    /** What customers owe, grouped by how old the unpaid bill is: 0-30, 31-60, 61-90, over 90 days. */
    public function creditAge(): JsonResponse
    {
        $now = now();
        $buckets = [
            'd0_30' => ['key' => 'd0_30', 'label' => '0-30 days', 'bills' => 0, 'amount' => 0],
            'd31_60' => ['key' => 'd31_60', 'label' => '31-60 days', 'bills' => 0, 'amount' => 0],
            'd61_90' => ['key' => 'd61_90', 'label' => '61-90 days', 'bills' => 0, 'amount' => 0],
            'd90_plus' => ['key' => 'd90_plus', 'label' => 'Over 90 days', 'bills' => 0, 'amount' => 0],
        ];
        $customers = [];

        $unpaid = Sale::with('customer:id,name,phone')
            ->whereNull('cancelled_at')->whereNotNull('customer_id')
            ->whereRaw('total - returned_total - paid > 0')
            ->get(['id', 'customer_id', 'total', 'returned_total', 'paid', 'sold_at']);

        foreach ($unpaid as $sale) {
            $age = (int) $sale->sold_at->diffInDays($now);
            $key = match (true) {
                $age <= 30 => 'd0_30',
                $age <= 60 => 'd31_60',
                $age <= 90 => 'd61_90',
                default => 'd90_plus',
            };
            $owes = $sale->balance();
            $buckets[$key]['bills']++;
            $buckets[$key]['amount'] += $owes;

            $c = &$customers[$sale->customer_id];
            $c ??= ['customer_id' => $sale->customer_id, 'name' => $sale->customer?->name, 'phone' => $sale->customer?->phone, 'owes' => 0, 'oldest_days' => 0, 'bucket' => $key];
            $c['owes'] += $owes;
            if ($age >= $c['oldest_days']) {
                $c['oldest_days'] = $age;
                $c['bucket'] = $key;
            }
            unset($c);
        }

        usort($customers, fn ($a, $b) => [$b['oldest_days'], $b['owes']] <=> [$a['oldest_days'], $a['owes']]);

        return response()->json([
            'as_of' => $now->toDateString(),
            'total' => array_sum(array_column($buckets, 'amount')),
            'buckets' => array_values($buckets),
            'customers' => $customers,
        ]);
    }

    /** Sales per staff member (sales minus goods sent back), highest first. */
    public function staff(ReportRequest $request): JsonResponse
    {
        [$from, $to] = $this->range($request);

        $rows = Sale::whereBetween('sold_at', [$from, $to])
            ->leftJoin('users', 'users.id', '=', 'sales.user_id')
            ->groupBy('sales.user_id', 'users.name')
            ->selectRaw('sales.user_id AS user_id, users.name AS name, COUNT(*) AS bills, SUM(sales.total - sales.returned_total) AS amount, SUM(sales.discount) AS discount')
            ->orderByDesc('amount')
            ->get();

        return response()->json([
            'from' => $request->input('from'),
            'to' => $request->input('to'),
            'data' => $rows->map(fn ($r) => [
                'user_id' => $r->user_id,
                'name' => $r->name ?? 'Unknown',
                'bills' => (int) $r->bills,
                'sales' => (int) $r->amount,
                'discount' => (int) $r->discount,
            ])->values(),
        ]);
    }
}
