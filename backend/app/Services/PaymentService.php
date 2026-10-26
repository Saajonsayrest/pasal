<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Payment;
use App\Models\Purchase;
use App\Models\Sale;
use App\Models\Supplier;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Records money in (from a customer) or out (to a supplier) against one sale or purchase.
 * The row is locked while we check the balance, so two payments cannot overpay it.
 */
class PaymentService
{
    public function record(Model $target, int $amount, ?int $userId, ?string $method = null, $paidAt = null): Payment
    {
        return DB::transaction(function () use ($target, $amount, $userId, $method, $paidAt) {
            $locked = $target::whereKey($target->getKey())->lockForUpdate()->firstOrFail();
            $left = $this->balanceOf($locked);

            if ($amount > $left) {
                throw ValidationException::withMessages([
                    'amount' => ["Amount is more than the balance. Only {$left} is left to pay."],
                ]);
            }

            $locked->paid += $amount;
            $locked->save();
            $target->paid = $locked->paid;

            return $this->createPayment($locked, $amount, $userId, $method, $paidAt);
        });
    }

    /**
     * One payment from a customer (or to a supplier) that covers their oldest unpaid bills first.
     * Every bill it touches gets its own payment row, so each bill's history stays complete.
     *
     * @return array{payments: Collection<int, Payment>, owes_left: int}
     */
    public function allocate(Customer|Supplier $party, int $amount, ?int $userId, ?string $method = null, $paidAt = null): array
    {
        return DB::transaction(function () use ($party, $amount, $userId, $method, $paidAt) {
            $bills = $party instanceof Customer
                ? Sale::where('customer_id', $party->id)->whereRaw('total - returned_total - paid > 0')->orderBy('sold_at')->orderBy('id')
                : Purchase::where('supplier_id', $party->id)->whereColumn('paid', '<', 'total')->orderBy('bought_at')->orderBy('id');

            $bills = $bills->lockForUpdate()->get();
            $owes = $bills->sum(fn ($b) => $this->balanceOf($b));

            if ($amount > $owes) {
                throw ValidationException::withMessages([
                    'amount' => ["Amount is more than what is owed. Only {$owes} is left to pay."],
                ]);
            }

            $payments = collect();
            $left = $amount;

            foreach ($bills as $bill) {
                if ($left === 0) {
                    break;
                }
                $part = min($left, $this->balanceOf($bill));
                $bill->paid += $part;
                $bill->save();
                $payments->push($this->createPayment($bill, $part, $userId, $method, $paidAt));
                $left -= $part;
            }

            return ['payments' => $payments, 'owes_left' => $owes - $amount];
        });
    }

    /** What is still open on a sale (after returns) or a purchase. */
    private function balanceOf(Model $bill): int
    {
        return $bill instanceof Sale ? $bill->balance() : $bill->total - $bill->paid;
    }

    private function createPayment(Model $bill, int $amount, ?int $userId, ?string $method, $paidAt): Payment
    {
        return Payment::create([
            'direction' => $bill instanceof Sale ? 'in' : 'out',
            'sale_id' => $bill instanceof Sale ? $bill->id : null,
            'purchase_id' => $bill instanceof Purchase ? $bill->id : null,
            'amount' => $amount,
            'paid_at' => $paidAt ?? now(),
            'method' => $method ?? 'cash',
            'user_id' => $userId,
        ]);
    }
}
