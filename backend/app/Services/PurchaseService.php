<?php

namespace App\Services;

use App\Models\Item;
use App\Models\Purchase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PurchaseService
{
    public function __construct(private StockService $stock, private PaymentService $payments) {}

    /**
     * @param  array{supplier_id: int, paid?: int, bought_at?: string|null, note?: string|null, items: array<int, array{item_id: int, quantity: int, unit_cost: int}>}  $data
     */
    public function create(array $data, int $userId): Purchase
    {
        $paid = (int) ($data['paid'] ?? 0);
        $lines = collect($data['items'])->sortBy('item_id')->values();

        return DB::transaction(function () use ($data, $userId, $paid, $lines) {
            $items = Item::whereIn('id', $lines->pluck('item_id'))->get()->keyBy('id');
            // Unit costs are without VAT. The VAT amount is copied from the supplier's bill.
            $total = $lines->sum(fn ($l) => (int) $l['quantity'] * (int) $l['unit_cost']) + (int) ($data['vat_amount'] ?? 0);

            if ($paid > $total) {
                throw ValidationException::withMessages(['paid' => ['Paid is more than the total.']]);
            }

            $purchase = new Purchase([
                'supplier_id' => $data['supplier_id'],
                'total' => $total,
                'bought_at' => $data['bought_at'] ?? now(),
                'user_id' => $userId,
                'note' => $data['note'] ?? null,
                'bill_no' => $data['bill_no'] ?? null,
                'bill_date' => $data['bill_date'] ?? null,
                'vat_amount' => (int) ($data['vat_amount'] ?? 0),
            ]);
            $purchase->paid = 0;
            $purchase->save();

            foreach ($lines as $line) {
                $item = $items[$line['item_id']];
                $purchase->items()->create([
                    'item_id' => $item->id,
                    'quantity' => (int) $line['quantity'],
                    'unit_cost' => (int) $line['unit_cost'],
                ]);
                $this->stock->move($item, (int) $line['quantity'], 'purchase', $userId, $purchase);
                $item->update(['cost_price' => (int) $line['unit_cost']]); // newest cost wins
            }

            if ($paid > 0) {
                $this->payments->record($purchase, $paid, $userId, $data['method'] ?? null, $purchase->bought_at);
            }

            return $purchase->load('items.item', 'supplier');
        });
    }
}
