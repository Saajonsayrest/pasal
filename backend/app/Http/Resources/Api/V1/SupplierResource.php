<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

class SupplierResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'address' => $this->address,
            'pan' => $this->pan,
            'note' => $this->note,
            // Only when the query asked for them (the suppliers list and a single supplier).
            'we_owe' => $this->when(isset($this->we_owe), fn () => (int) $this->we_owe), // paisa still to pay
            'last_purchase_at' => $this->when(isset($this->we_owe), fn () => $this->last_purchase_at ? Carbon::parse($this->last_purchase_at)->toIso8601String() : null),
        ];
    }
}
