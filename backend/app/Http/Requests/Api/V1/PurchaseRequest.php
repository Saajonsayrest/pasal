<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class PurchaseRequest extends FormRequest
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
            'supplier_id' => ['required', 'integer', CurrentBusiness::exists('suppliers', 'id', softDeletes: true)],
            'paid' => ['nullable', 'integer', 'min:0', 'max:1000000000000000'],
            'method' => ['nullable', 'string', 'max:20'],
            'bought_at' => ['nullable', 'date'],
            'note' => ['nullable', 'string', 'max:255'],
            'bill_no' => ['nullable', 'string', 'max:50'],
            'bill_date' => ['nullable', 'date'],
            'vat_amount' => ['nullable', 'integer', 'min:0', 'max:1000000000000'],
            'items' => ['required', 'array', 'min:1', 'max:100'],
            'items.*.item_id' => ['required', 'integer', CurrentBusiness::exists('items', 'id', softDeletes: true)],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:1000000'],
            'items.*.unit_cost' => ['required', 'integer', 'min:0', 'max:10000000000'],
        ];
    }
}
