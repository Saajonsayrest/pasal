<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\Sale;
use App\Models\User;
use App\Models\VatFiling;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Things that need attention right now. Worked out when asked, so nothing is stored and there is
 * no "read" mark yet. The apps keep their own "seen" time.
 * VAT due dates by Nepali month are worked out in the apps, which know the Nepali calendar.
 */
class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $owner = $request->user()->isOwner();
        $now = now();
        $data = [];

        $low = Item::lowStock()->orderBy('name')->get(['id', 'name', 'quantity', 'low_stock_at']);
        if ($low->isNotEmpty()) {
            $data[] = [
                'type' => 'low_stock',
                'title' => $low->count().' '.($low->count() === 1 ? 'item is' : 'items are').' low on stock',
                'body' => $low->take(3)->pluck('name')->implode(', ').($low->count() > 3 ? ' and more' : ''),
                'count' => $low->count(),
                'at' => $now->toIso8601String(),
            ];
        }

        $overdue = Sale::with('customer:id,name')
            ->whereNull('cancelled_at')->whereNotNull('customer_id')
            ->whereRaw('total - returned_total - paid > 0')
            ->where('sold_at', '<', $now->copy()->subDays(30))
            ->get(['id', 'customer_id', 'total', 'returned_total', 'paid', 'sold_at']);
        if ($overdue->isNotEmpty()) {
            $names = $overdue->pluck('customer.name')->unique()->values();
            $data[] = [
                'type' => 'credit_overdue',
                'title' => $names->count().' '.($names->count() === 1 ? 'customer has' : 'customers have').' not paid for over 30 days',
                'body' => $names->take(3)->implode(', ').($names->count() > 3 ? ' and more' : ''),
                'count' => $names->count(),
                'amount' => $overdue->sum(fn ($s) => $s->balance()),
                'at' => $now->toIso8601String(),
            ];
        }

        if ($owner) {
            $unfiled = VatFiling::whereNull('filed_on')->orderBy('period_to')->get();
            foreach ($unfiled as $f) {
                $due = $f->period_to->copy()->addDays((int) config('pasal.vat_due_days'));
                $data[] = [
                    'type' => 'vat_unfiled',
                    'title' => 'VAT '.$f->period.' is saved but not filed',
                    'body' => 'Due '.$due->toDateString(),
                    'due_date' => $due->toDateString(),
                    'at' => $now->toIso8601String(),
                ];
            }

            $newStaff = User::where('business_id', $request->user()->business_id)
                ->where('id', '!=', $request->user()->id)
                ->where('created_at', '>=', $now->copy()->subDays(7))
                ->orderByDesc('created_at')->get();
            foreach ($newStaff as $u) {
                $data[] = [
                    'type' => 'staff_added',
                    'title' => $u->name.' joined as '.$u->role,
                    'body' => $u->email,
                    'at' => $u->created_at->toIso8601String(),
                ];
            }
        }

        return response()->json(['data' => $data]);
    }
}
