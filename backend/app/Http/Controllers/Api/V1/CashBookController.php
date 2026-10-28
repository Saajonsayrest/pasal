<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\ShopDay;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Owner only. Every rupee that came in or went out, in the order it happened, with a running balance.
 *   in:  payments from customers
 *   out: refunds to customers, payments to suppliers, expenses
 */
class CashBookController extends Controller
{
    private const ENTRIES = "
        SELECT CASE p.direction WHEN 'in' THEN 'payment_in' WHEN 'refund' THEN 'refund' ELSE 'payment_out' END AS kind,
               p.id AS id, p.paid_at AS at,
               (CASE p.direction WHEN 'in' THEN p.amount ELSE -p.amount END)::bigint AS amount,
               p.method AS method, COALESCE(c.name, su.name) AS label
        FROM payments p
        LEFT JOIN sales s ON s.id = p.sale_id
        LEFT JOIN customers c ON c.id = s.customer_id
        LEFT JOIN purchases pu ON pu.id = p.purchase_id
        LEFT JOIN suppliers su ON su.id = pu.supplier_id
        WHERE p.business_id = :business_a
        UNION ALL
        SELECT 'expense', e.id, e.spent_at, (-e.amount)::bigint, 'cash', e.title
        FROM expenses e
        WHERE e.business_id = :business_b
    ";

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'page' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        // Nepal days, both included; the stored times are UTC.
        $fromDate = $request->date('from')->toDateString();
        $toDate = $request->date('to')->toDateString();
        $from = ShopDay::start($fromDate);
        $to = ShopDay::end($toDate);
        $perPage = (int) $request->query('per_page', 50);
        $page = (int) $request->query('page', 1);
        $ids = ['business_a' => $request->user()->business_id, 'business_b' => $request->user()->business_id];

        $totals = DB::selectOne('
            SELECT COALESCE(SUM(amount) FILTER (WHERE at < :from_a), 0)::bigint AS opening,
                   COALESCE(SUM(amount) FILTER (WHERE at BETWEEN :from_b AND :to_a AND amount > 0), 0)::bigint AS money_in,
                   COALESCE(-SUM(amount) FILTER (WHERE at BETWEEN :from_c AND :to_b AND amount < 0), 0)::bigint AS money_out,
                   COUNT(*) FILTER (WHERE at BETWEEN :from_d AND :to_c) AS entries
            FROM ('.self::ENTRIES.') t', $ids + [
            'from_a' => $from, 'from_b' => $from, 'from_c' => $from, 'from_d' => $from,
            'to_a' => $to, 'to_b' => $to, 'to_c' => $to,
        ]);

        // The running balance is worked out over everything before the page, so it is right on every page.
        $rows = DB::select('
            SELECT * FROM (
                SELECT t.*, SUM(t.amount) OVER (ORDER BY t.at, t.kind, t.id)::bigint AS balance
                FROM ('.self::ENTRIES.') t
            ) r
            WHERE r.at BETWEEN :from AND :to
            ORDER BY r.at, r.kind, r.id
            LIMIT :limit OFFSET :offset
        ', $ids + ['from' => $from, 'to' => $to, 'limit' => $perPage, 'offset' => ($page - 1) * $perPage]);

        return response()->json([
            'from' => $fromDate,
            'to' => $toDate,
            'opening_balance' => (int) $totals->opening,
            'money_in' => (int) $totals->money_in,
            'money_out' => (int) $totals->money_out,
            'closing_balance' => (int) $totals->opening + (int) $totals->money_in - (int) $totals->money_out,
            'data' => collect($rows)->map(fn ($r) => [
                'kind' => $r->kind, // payment_in | payment_out | refund | expense
                'id' => (int) $r->id,
                'at' => Carbon::parse($r->at)->toIso8601String(),
                'amount' => (int) $r->amount, // negative = money out
                'method' => $r->method,
                'label' => $r->label,
                'balance' => (int) $r->balance,
            ]),
            'meta' => ['current_page' => $page, 'per_page' => $perPage, 'total' => (int) $totals->entries],
        ]);
    }
}
