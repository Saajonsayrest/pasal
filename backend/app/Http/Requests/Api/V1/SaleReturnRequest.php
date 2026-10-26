<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class SaleReturnRequest extends FormRequest
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
            'items' => ['required', 'array', 'min:1', 'max:100'],
            'items.*.sale_item_id' => ['required', 'integer', CurrentBusiness::exists('sale_items')],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:1000000'],
            'restock' => ['nullable', 'boolean'], // false = goods are damaged, do not put them back on the shelf
            'note' => ['nullable', 'string', 'max:255'],
        ];
    }
}
