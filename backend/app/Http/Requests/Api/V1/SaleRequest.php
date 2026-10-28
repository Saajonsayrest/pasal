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
        $isOwner = $this->user()->isOwner();

        // Staff sell at the list price, today, with the next bill number. Changing any of these is owner work,
        // because a custom price would get around the staff discount cap.
        return [
            'customer_id' => ['nullable', 'integer', CurrentBusiness::exists('customers', 'id', softDeletes: true)],
            'paid' => ['nullable', 'integer', 'min:0', 'max:1000000000000000'],
            'discount' => ['nullable', 'integer', 'min:0', 'max:1000000000000000'], // off the whole bill, VAT included
            // Only the owner can sell on udhar past a customer's limit.
            'ignore_credit_limit' => $isOwner ? ['nullable', 'boolean'] : ['prohibited'],
            'method' => ['nullable', 'string', 'max:20'],
            'sold_at' => $isOwner ? ['nullable', 'date'] : ['prohibited'],
            'note' => ['nullable', 'string', 'max:255'],
            'bill_no' => $isOwner ? ['nullable', 'string', 'max:50'] : ['prohibited'],
            'items' => ['required', 'array', 'min:1', 'max:100'],
            'items.*.item_id' => ['required', 'integer', CurrentBusiness::exists('items', 'id', softDeletes: true)],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:1000000'],
            'items.*.unit_price' => $isOwner ? ['nullable', 'integer', 'min:0', 'max:10000000000'] : ['prohibited'],
        ];
    }
}
