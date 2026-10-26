<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class SaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'customer_id' => ['nullable', 'integer', CurrentBusiness::exists('customers', 'id', softDeletes: true)],
            'paid' => ['nullable', 'integer', 'min:0', 'max:1000000000000000'],
            'discount' => ['nullable', 'integer', 'min:0', 'max:1000000000000000'], // off the whole bill, VAT included
            // Only the owner can sell on udhar past a customer's limit.
            'ignore_credit_limit' => $this->user()->isOwner() ? ['nullable', 'boolean'] : ['prohibited'],
            'method' => ['nullable', 'string', 'max:20'],
            'sold_at' => ['nullable', 'date'],
            'note' => ['nullable', 'string', 'max:255'],
            'bill_no' => ['nullable', 'string', 'max:50'],
            'items' => ['required', 'array', 'min:1', 'max:100'],
            'items.*.item_id' => ['required', 'integer', CurrentBusiness::exists('items', 'id', softDeletes: true)],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:1000000'],
            'items.*.unit_price' => ['nullable', 'integer', 'min:0', 'max:10000000000'],
        ];
    }
}
