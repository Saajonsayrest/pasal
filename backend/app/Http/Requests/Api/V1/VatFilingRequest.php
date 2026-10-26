<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class VatFilingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * For a computed filing send period, from, to and optional opening_carry.
     * For an old return typed in by hand ("manual": true) send every amount too.
     *
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        $manual = $this->boolean('manual');

        $amount = $manual ? ['required', 'integer', 'min:0'] : ['prohibited'];

        return [
            'period' => ['required', 'string', 'max:20', CurrentBusiness::unique('vat_filings', 'period')],
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'manual' => ['nullable', 'boolean'],
            'opening_carry' => ['nullable', 'integer', 'min:0'],
            'sales_taxable' => $amount,
            'sales_exempt' => $amount,
            'output_vat' => $amount,
            'purchases_taxable' => $amount,
            'input_vat' => $amount,
            'carry_in' => $amount,
            'payable' => $amount,
            'carry_out' => $amount,
            'filed_on' => ['nullable', 'date'],
            'paid_amount' => ['nullable', 'integer', 'min:0'],
            'paid_on' => ['nullable', 'date'],
            'receipt_no' => ['nullable', 'string', 'max:60'],
            'note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
