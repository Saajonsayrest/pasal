<?php

namespace App\Services;

use App\Models\Item;
use App\Models\Payment;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Goods coming back, or a whole sale cancelled.
 *
 * The sale row is never rewritten. A return is its own row, counted on the day it happened.
 * What the customer owes goes down first. If they already paid more than the new total,
 * the extra is paid back in cash (a "refund" payment).
 */
class SaleReturnService
{
    public function __construct(private StockService $stock) {}

    /**
     * @param  array<int, array{sale_item_id: int, quantity: int}>|null  $lines  null = cancel the whole sale
     */
    public function process(Sale $sale, ?array $lines, bool $restock, ?string $note, int $userId): SaleReturn
    {
        return DB::transaction(function () use ($sale, $lines, $restock, $note, $userId) {
            $locked = Sale::whereKey($sale->id)->lockForUpdate()->firstOrFail();

            if ($locked->cancelled_at) {
                throw ValidationException::withMessages(['sale' => ['This sale is already cancelled.']]);
            }

            $saleItems = SaleItem::where('sale_id', $locked->id)->orderBy('id')->lockForUpdate()->get()->keyBy('id');
            $wanted = $this->wantedQuantities($saleItems, $lines);

            $total = 0;
            $vatGross = 0;
            $cost = 0;
            $rows = [];

            foreach ($wanted as $saleItemId => $quantity) {
                $line = $saleItems[$saleItemId];
                $amount = $this->lineAmount($line, $quantity);

                $total += $amount;
                $cost += $quantity * $line->unit_cost;
                if ($line->vat_applies) {
                    $vatGross += $amount;
                }
                $rows[] = ['line' => $line, 'quantity' => $quantity, 'amount' => $amount];
            }

            [$vat, $taxable, $exempt] = $this->vatOf($locked, $total, $vatGross);

            $kind = $lines === null ? 'cancel' : 'return';
            $return = new SaleReturn;
            $return->forceFill([
                'sale_id' => $locked->id,
                'user_id' => $userId,
                'kind' => $kind,
                'returned_at' => now(),
                'total' => $total,
                'taxable_amount' => $taxable,
                'vat_amount' => $vat,
                'exempt_amount' => $exempt,
                'cost' => $cost,
                'refunded' => 0,
                'restocked' => $restock,
                'note' => $note,
            ])->save();

            // Same lock order as a sale: by item id.
            foreach (collect($rows)->sortBy(fn ($r) => $r['line']->item_id) as $row) {
                $line = $row['line'];
                $line->returned_quantity += $row['quantity'];
                $line->returned_amount += $row['amount'];
                $line->save();

                $return->items()->make()->forceFill([
                    'business_id' => $locked->business_id,
                    'sale_item_id' => $line->id,
                    'quantity' => $row['quantity'],
                    'amount' => $row['amount'],
                ])->save();

                if ($restock) {
                    $this->stock->move(Item::withTrashed()->findOrFail($line->item_id), $row['quantity'], $kind === 'cancel' ? 'sale_cancel' : 'sale_return', $userId, $locked, $note);
                }
            }

            $locked->returned_total += $total;
            $everythingBack = $saleItems->every(fn ($l) => $l->returned_quantity === $l->quantity);
            if ($everythingBack) {
                $locked->cancelled_at = now();
            }

            // The customer paid more than what is left of the bill: give the extra back.
            $refund = max(0, $locked->paid - ($locked->total - $locked->returned_total));
            if ($refund > 0) {
                $locked->paid -= $refund;
                Payment::create([
                    'direction' => 'refund',
                    'sale_id' => $locked->id,
                    'amount' => $refund,
                    'paid_at' => now(),
                    'method' => 'cash',
                    'user_id' => $userId,
                ]);
                $return->forceFill(['refunded' => $refund])->save();
            }
            $locked->save();

            return $return->load('items');
        });
    }

    /**
     * @param  Collection<int, SaleItem>  $saleItems
     * @param  array<int, array{sale_item_id: int, quantity: int}>|null  $lines
     * @return array<int, int> sale_item_id => quantity
     */
    private function wantedQuantities($saleItems, ?array $lines): array
    {
        $wanted = [];

        if ($lines === null) {
            foreach ($saleItems as $id => $line) {
                if ($line->quantity > $line->returned_quantity) {
                    $wanted[$id] = $line->quantity - $line->returned_quantity;
                }
            }
        } else {
            foreach ($lines as $i => $row) {
                $id = (int) $row['sale_item_id'];
                if (! isset($saleItems[$id])) {
                    throw ValidationException::withMessages(["items.{$i}.sale_item_id" => ['This line is not on this sale.']]);
                }
                $wanted[$id] = ($wanted[$id] ?? 0) + (int) $row['quantity'];
            }

            foreach ($wanted as $id => $quantity) {
                $left = $saleItems[$id]->quantity - $saleItems[$id]->returned_quantity;
                if ($quantity > $left) {
                    throw ValidationException::withMessages(['items' => ["Only {$left} of this line can still be returned."]]);
                }
            }
        }

        if ($wanted === []) {
            throw ValidationException::withMessages(['items' => ['Nothing is left to return on this sale.']]);
        }

        return $wanted;
    }

    /** The value of $quantity units of a line. The last units take whatever is left, so the paisa always add up. */
    private function lineAmount(SaleItem $line, int $quantity): int
    {
        $left = $line->net() - $line->returned_amount;

        if ($quantity === $line->quantity - $line->returned_quantity) {
            return $left;
        }

        return min((int) round($line->net() * $quantity / $line->quantity), $left);
    }

    /**
     * @return array{0: int, 1: int, 2: int} vat, taxable, exempt
     */
    private function vatOf(Sale $sale, int $total, int $vatGross): array
    {
        $alreadyBack = (int) SaleReturn::where('sale_id', $sale->id)->sum('vat_amount');
        $left = $sale->vat_amount - $alreadyBack;

        $rate = (float) $sale->vat_rate;
        $vat = $sale->returned_total + $total === $sale->total
            ? $left // the last return takes the exact rest
            : min((int) round($vatGross * $rate / (100 + $rate)), $left);

        return [$vat, max($vatGross - $vat, 0), $total - $vatGross];
    }
}
