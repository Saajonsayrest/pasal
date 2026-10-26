<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SaleResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bill_no' => $this->bill_no,
            'customer_id' => $this->customer_id,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'total' => $this->total,
            'paid' => $this->paid,
            'balance' => $this->total - $this->paid,
            'vat_rate' => (float) $this->vat_rate,
            'taxable_amount' => $this->taxable_amount,
            'vat_amount' => $this->vat_amount,
            'exempt_amount' => $this->exempt_amount,
            'sold_at' => $this->sold_at?->toIso8601String(),
            'note' => $this->note,
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($line) => [
                'item_id' => $line->item_id,
                'item_name' => $line->item?->name,
                'quantity' => $line->quantity,
                'unit_price' => $line->unit_price,
                'line_total' => $line->quantity * $line->unit_price,
            ])),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
        ];
    }
}
