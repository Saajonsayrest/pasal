<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SaleReturnResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'sale_id' => $this->sale_id,
            'kind' => $this->kind, // return | cancel
            'returned_at' => $this->returned_at?->toIso8601String(),
            'total' => $this->total,
            'vat_amount' => $this->vat_amount,
            'refunded' => $this->refunded, // cash paid back to the customer
            'restocked' => $this->restocked,
            'note' => $this->note,
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($row) => [
                'sale_item_id' => $row->sale_item_id,
                'quantity' => $row->quantity,
                'amount' => $row->amount,
            ])),
        ];
    }
}
