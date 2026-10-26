<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Item;
use App\Models\Sale;
use App\Support\BillNumber;
use App\Support\CurrentBusiness;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleService
{
    public function __construct(private StockService $stock, private PaymentService $payments) {}

    /**
     * @param  array{customer_id?: int|null, paid?: int, discount?: int, ignore_credit_limit?: bool, sold_at?: string|null, note?: string|null, items: array<int, array{item_id: int, quantity: int, unit_price?: int|null}>}  $data
     */
    public function create(array $data, int $userId, ?int $discountCapPercent = null): Sale
    {
        $paid = (int) ($data['paid'] ?? 0);
        $discount = (int) ($data['discount'] ?? 0);
        $lines = collect($data['items'])->sortBy('item_id')->values(); // same lock order every time

        return DB::transaction(function () use ($data, $userId, $paid, $discount, $lines, $discountCapPercent) {
            $items = Item::whereIn('id', $lines->pluck('item_id'))->get()->keyBy('id');

            $prepared = $lines->map(function ($line) use ($items) {
                $item = $items[$line['item_id']];
                $quantity = (int) $line['quantity'];
                $unitPrice = (int) ($line['unit_price'] ?? $item->sell_price);

                return [
                    'item' => $item,
                    'quantity' => $quantity,
                    'unit_price' => $unitPrice,
                    'unit_cost' => $item->cost_price,
                    'gross' => $quantity * $unitPrice,
                ];
            });

            $subtotal = $prepared->sum('gross');

            if ($discount > $subtotal) {
                throw ValidationException::withMessages(['discount' => ['Discount is more than the bill.']]);
            }

            // Staff can give a small discount at the counter. A bigger one needs the owner.
            if ($discountCapPercent !== null && $discount * 100 > $subtotal * $discountCapPercent) {
                throw ValidationException::withMessages(['discount' => ["Staff can give at most {$discountCapPercent}% discount. Ask the owner for more."]]);
            }

            $shares = $this->splitDiscount($prepared->pluck('gross')->all(), $discount, $subtotal);
            $prepared = $prepared->map(fn ($l, $i) => $l + ['discount' => $shares[$i], 'net' => $l['gross'] - $shares[$i]]);

            $total = $subtotal - $discount;

            // Prices include VAT. Pull the VAT part out of the lines that carry VAT, after the discount.
            $rate = (float) CurrentBusiness::business()->vat_rate;
            $vatLines = $prepared->filter(fn ($l) => $l['item']->vat_applies)->sum('net');
            $vat = (int) round($vatLines * $rate / (100 + $rate));

            if ($paid > $total) {
                throw ValidationException::withMessages(['paid' => ['Paid is more than the total.']]);
            }
            if ($paid < $total && empty($data['customer_id'])) {
                throw ValidationException::withMessages(['customer_id' => ['Pick a customer when the sale is not fully paid (udhar).']]);
            }
            if ($paid < $total) {
                $this->checkCreditLimit((int) $data['customer_id'], $total - $paid, (bool) ($data['ignore_credit_limit'] ?? false));
            }

            $sale = new Sale([
                'customer_id' => $data['customer_id'] ?? null,
                'total' => $total,
                'sold_at' => $data['sold_at'] ?? now(),
                'user_id' => $userId,
                'note' => $data['note'] ?? null,
                'bill_no' => ($data['bill_no'] ?? null) ?: BillNumber::nextSale(),
            ]);
            $sale->subtotal = $subtotal;
            $sale->discount = $discount;
            $sale->paid = 0;
            $sale->vat_rate = $rate;
            $sale->vat_amount = $vat;
            $sale->taxable_amount = $vatLines - $vat;
            $sale->exempt_amount = $total - $vatLines;
            $sale->save();

            foreach ($prepared as $line) {
                $row = $sale->items()->make([
                    'item_id' => $line['item']->id,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'unit_cost' => $line['unit_cost'],
                ]);
                $row->discount = $line['discount'];
                $row->vat_applies = $line['item']->vat_applies;
                $row->save();

                $this->stock->move($line['item'], -$line['quantity'], 'sale', $userId, $sale);
            }

            if ($paid > 0) {
                $this->payments->record($sale, $paid, $userId, $data['method'] ?? null, $sale->sold_at);
            }

            return $sale->load('items.item', 'customer');
        });
    }

    /**
     * Share a bill discount over the lines in proportion to their price. The shares always add up to the discount.
     *
     * @param  array<int, int>  $grosses
     * @return array<int, int>
     */
    private function splitDiscount(array $grosses, int $discount, int $subtotal): array
    {
        if ($discount === 0 || $subtotal === 0) {
            return array_fill(0, count($grosses), 0);
        }

        $shares = [];
        $fractions = [];
        foreach ($grosses as $i => $gross) {
            $shares[$i] = intdiv($discount * $gross, $subtotal);
            $fractions[$i] = ($discount * $gross) % $subtotal;
        }

        // The left-over paisa go to the lines with the biggest remainder.
        $left = $discount - array_sum($shares);
        arsort($fractions);
        foreach (array_keys($fractions) as $i) {
            if ($left <= 0 || $fractions[$i] === 0) {
                break;
            }
            $shares[$i]++;
            $left--;
        }

        return $shares;
    }

    /**
     * The customer row is locked, so two udhar sales at the same moment cannot both pass the limit.
     */
    private function checkCreditLimit(int $customerId, int $newDebt, bool $ignore): void
    {
        $customer = Customer::whereKey($customerId)->lockForUpdate()->firstOrFail();

        if ($customer->credit_limit === null || $ignore) {
            return;
        }

        $owes = (int) Sale::where('customer_id', $customerId)
            ->selectRaw('COALESCE(SUM(total - returned_total - paid), 0) AS owes')->value('owes');

        if ($owes + $newDebt > $customer->credit_limit) {
            throw ValidationException::withMessages([
                'customer_id' => ["This sale is over the credit limit of {$customer->credit_limit}. The customer already owes {$owes}."],
            ]);
        }
    }
}
