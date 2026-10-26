<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class StockAdjustmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'item_id' => ['required', 'integer', CurrentBusiness::exists('items', 'id', softDeletes: true)],
            'change' => ['required', 'integer', 'not_in:0', 'between:-1000000,1000000'],
            'note' => ['required', 'string', 'max:255'],
        ];
    }
}
