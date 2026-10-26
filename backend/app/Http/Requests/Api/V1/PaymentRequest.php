<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class PaymentRequest extends FormRequest
{
    /** Staff take money from customers. Paying suppliers is the owner's job. */
    public function authorize(): bool
    {
        return ! $this->filled('purchase_id') || $this->user()->isOwner();
    }

    /**
     * Send exactly one of sale_id (money in) or purchase_id (money out).
     *
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'sale_id' => ['required_without:purchase_id', 'prohibits:purchase_id', 'nullable', 'integer', CurrentBusiness::exists('sales')],
            'purchase_id' => ['required_without:sale_id', 'prohibits:sale_id', 'nullable', 'integer', CurrentBusiness::exists('purchases')],
            'amount' => ['required', 'integer', 'min:1', 'max:1000000000000000'],
            'method' => ['nullable', 'string', 'max:20'],
            'paid_at' => ['nullable', 'date'],
        ];
    }
}
