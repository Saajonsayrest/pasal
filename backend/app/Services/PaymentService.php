<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\Purchase;
use App\Models\Sale;
use Illuminate\Database\Eloquent\Model;
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
            $left = $locked->total - $locked->paid;

            if ($amount > $left) {
                throw ValidationException::withMessages([
                    'amount' => ["Amount is more than the balance. Only {$left} is left to pay."],
                ]);
            }

            $locked->paid += $amount;
            $locked->save();
            $target->paid = $locked->paid;

            return Payment::create([
                'direction' => $target instanceof Sale ? 'in' : 'out',
                'sale_id' => $target instanceof Sale ? $target->id : null,
                'purchase_id' => $target instanceof Purchase ? $target->id : null,
                'amount' => $amount,
                'paid_at' => $paidAt ?? now(),
                'method' => $method ?? 'cash',
                'user_id' => $userId,
            ]);
        });
    }
}
