<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'direction' => $this->direction,
            'sale_id' => $this->sale_id,
            'purchase_id' => $this->purchase_id,
            'amount' => $this->amount,
            'method' => $this->method,
            'paid_at' => $this->paid_at?->toIso8601String(),
        ];
    }
}
