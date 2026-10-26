<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'sku' => $this->sku,
            'unit' => $this->unit,
            'vat_applies' => $this->vat_applies,
            // Staff must not see what the shop paid, because that shows the profit.
            'cost_price' => $request->user()?->isOwner() ? $this->cost_price : null,
            'sell_price' => $this->sell_price,
            'quantity' => $this->quantity,
            'low_stock_at' => $this->low_stock_at,
            'is_low_stock' => $this->quantity <= $this->low_stock_at,
        ];
    }
}
