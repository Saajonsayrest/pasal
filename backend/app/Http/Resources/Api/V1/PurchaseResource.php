<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PurchaseResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bill_no' => $this->bill_no,
            'bill_date' => $this->bill_date?->toDateString(),
            'supplier_id' => $this->supplier_id,
            'supplier' => new SupplierResource($this->whenLoaded('supplier')),
            'total' => $this->total,
            'paid' => $this->paid,
            'balance' => $this->total - $this->paid,
            'vat_amount' => $this->vat_amount,
            'bought_at' => $this->bought_at?->toIso8601String(),
            'note' => $this->note,
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($line) => [
                'item_id' => $line->item_id,
                'item_name' => $line->item?->name,
                'quantity' => $line->quantity,
                'unit_cost' => $line->unit_cost,
                'line_total' => $line->quantity * $line->unit_cost,
            ])),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
        ];
    }
}
