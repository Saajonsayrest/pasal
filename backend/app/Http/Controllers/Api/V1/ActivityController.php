<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Owner only. Who did what and when, read from the records the shop already keeps
 * (sales, returns, purchases, payments, expenses, stock changes made by hand, VAT filings).
 * Nothing extra is written, so it cannot drift from the real data.
 */
class ActivityController extends Controller
{
    private const EVENTS = "
        SELECT 'sale' AS kind, s.id AS ref_id, s.sold_at AS at, s.user_id, s.bill_no AS label, s.total::bigint AS amount
        FROM sales s WHERE s.business_id = :b1
        UNION ALL
        SELECT r.kind, r.sale_id, r.returned_at, r.user_id, sa.bill_no, r.total::bigint
        FROM sale_returns r JOIN sales sa ON sa.id = r.sale_id WHERE r.business_id = :b2
        UNION ALL
        SELECT 'purchase', p.id, p.bought_at, p.user_id, p.bill_no, p.total::bigint
        FROM purchases p WHERE p.business_id = :b3
        UNION ALL
        SELECT CASE p.direction WHEN 'in' THEN 'payment_in' WHEN 'refund' THEN 'refund' ELSE 'payment_out' END,
               p.id, p.paid_at, p.user_id, COALESCE(c.name, su.name), p.amount::bigint
        FROM payments p
        LEFT JOIN sales s ON s.id = p.sale_id LEFT JOIN customers c ON c.id = s.customer_id
        LEFT JOIN purchases pu ON pu.id = p.purchase_id LEFT JOIN suppliers su ON su.id = pu.supplier_id
        WHERE p.business_id = :b4
        UNION ALL
        SELECT 'expense', e.id, e.spent_at, e.user_id, e.title, e.amount::bigint
        FROM expenses e WHERE e.business_id = :b5
        UNION ALL
        SELECT 'stock_' || m.reason, m.item_id, m.created_at, m.user_id, i.name, m.change::bigint
        FROM stock_movements m JOIN items i ON i.id = m.item_id
        WHERE m.business_id = :b6 AND m.reason IN ('adjust', 'count')
        UNION ALL
        SELECT 'vat_filing', v.id, v.created_at, v.user_id, v.period, v.payable::bigint
        FROM vat_filings v WHERE v.business_id = :b7
    ";

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'page' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'user_id' => ['nullable', 'integer'],
        ]);

        $perPage = (int) $request->query('per_page', 30);
        $page = (int) $request->query('page', 1);
        $business = $request->user()->business_id;
        $ids = ['b1' => $business, 'b2' => $business, 'b3' => $business, 'b4' => $business, 'b5' => $business, 'b6' => $business, 'b7' => $business];
        $userFilter = $request->filled('user_id') ? ' WHERE e.user_id = :uid' : '';
        $params = $request->filled('user_id') ? $ids + ['uid' => (int) $request->query('user_id')] : $ids;

        $total = (int) DB::selectOne('SELECT COUNT(*) AS n FROM ('.self::EVENTS.') e'.$userFilter, $params)->n;

        $rows = DB::select(
            'SELECT e.*, u.name AS user_name FROM ('.self::EVENTS.') e
             LEFT JOIN users u ON u.id = e.user_id AND u.business_id = :ub'.$userFilter.'
             ORDER BY e.at DESC, e.kind, e.ref_id DESC LIMIT :limit OFFSET :offset',
            $params + ['ub' => $business, 'limit' => $perPage, 'offset' => ($page - 1) * $perPage]
        );

        return response()->json([
            'data' => collect($rows)->map(fn ($r) => [
                'kind' => $r->kind, // sale, return, cancel, purchase, payment_in, payment_out, refund, expense, stock_adjust, stock_count, vat_filing
                'ref_id' => (int) $r->ref_id,
                'at' => Carbon::parse($r->at)->toIso8601String(),
                'by' => $r->user_name,
                'label' => $r->label,
                'amount' => (int) $r->amount,
            ]),
            'meta' => ['current_page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]);
    }
}
