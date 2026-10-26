<?php

namespace App\Services;

use App\Models\Item;
use App\Models\Sale;
use App\Support\CurrentBusiness;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleService
{
    public function __construct(private StockService $stock, private PaymentService $payments) {}

    /**
     * @param  array{customer_id?: int|null, paid?: int, sold_at?: string|null, note?: string|null, items: array<int, array{item_id: int, quantity: int, unit_price?: int|null}>}  $data
     */
    public function create(array $data, int $userId): Sale
    {
        $paid = (int) ($data['paid'] ?? 0);
        $lines = collect($data['items'])->sortBy('item_id')->values(); // same lock order every time

        return DB::transaction(function () use ($data, $userId, $paid, $lines) {
            $items = Item::whereIn('id', $lines->pluck('item_id'))->get()->keyBy('id');

            $prepared = $lines->map(function ($line) use ($items) {
                $item = $items[$line['item_id']];

                return [
                    'item' => $item,
                    'quantity' => (int) $line['quantity'],
                    'unit_price' => (int) ($line['unit_price'] ?? $item->sell_price),
                    'unit_cost' => $item->cost_price,
                ];
            });

            $total = $prepared->sum(fn ($l) => $l['quantity'] * $l['unit_price']);

            // Prices include VAT. Pull the VAT part out of the lines that carry VAT.
            $rate = (float) CurrentBusiness::business()->vat_rate;
            $vatLines = $prepared->filter(fn ($l) => $l['item']->vat_applies)->sum(fn ($l) => $l['quantity'] * $l['unit_price']);
            $vat = (int) round($vatLines * $rate / (100 + $rate));

            if ($paid > $total) {
                throw ValidationException::withMessages(['paid' => ['Paid is more than the total.']]);
            }
            if ($paid < $total && empty($data['customer_id'])) {
                throw ValidationException::withMessages(['customer_id' => ['Pick a customer when the sale is not fully paid (udhar).']]);
            }

            $sale = new Sale([
                'customer_id' => $data['customer_id'] ?? null,
                'total' => $total,
                'sold_at' => $data['sold_at'] ?? now(),
                'user_id' => $userId,
                'note' => $data['note'] ?? null,
                'bill_no' => $data['bill_no'] ?? null,
            ]);
            $sale->paid = 0;
            $sale->vat_rate = $rate;
            $sale->vat_amount = $vat;
            $sale->taxable_amount = $vatLines - $vat;
            $sale->exempt_amount = $total - $vatLines;
            $sale->save();

            foreach ($prepared as $line) {
                $sale->items()->create([
                    'item_id' => $line['item']->id,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'unit_cost' => $line['unit_cost'],
                ]);
                $this->stock->move($line['item'], -$line['quantity'], 'sale', $userId, $sale);
            }

            if ($paid > 0) {
                $this->payments->record($sale, $paid, $userId, $data['method'] ?? null, $sale->sold_at);
            }

            return $sale->load('items.item', 'customer');
        });
    }
}
