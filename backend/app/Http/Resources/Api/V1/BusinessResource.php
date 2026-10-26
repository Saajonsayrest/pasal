<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BusinessResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'pan' => $this->pan,
            'phone' => $this->phone,
            'address' => $this->address,
            'vat_rate' => (float) $this->vat_rate,
        ];
    }
}
