<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

class CustomerResource extends JsonResource
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
            'credit_limit' => $this->credit_limit, // null = no limit
            // Only when the query asked for them (the customers list and a single customer).
            'owes' => $this->when(isset($this->owes), fn () => (int) $this->owes), // paisa still to collect
            'last_sale_at' => $this->when(isset($this->owes), fn () => $this->last_sale_at ? Carbon::parse($this->last_sale_at)->toIso8601String() : null),
            'oldest_unpaid_at' => $this->when(isset($this->owes), fn () => $this->oldest_unpaid_at ? Carbon::parse($this->oldest_unpaid_at)->toIso8601String() : null),
        ];
    }
}
