<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class VatFilingUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Only the "what happened after filing" fields can change. The numbers are frozen.
     *
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'filed_on' => ['nullable', 'date'],
            'paid_amount' => ['nullable', 'integer', 'min:0'],
            'paid_on' => ['nullable', 'date'],
            'receipt_no' => ['nullable', 'string', 'max:60'],
            'note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
