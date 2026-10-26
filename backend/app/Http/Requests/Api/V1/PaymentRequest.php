<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class PaymentRequest extends FormRequest
{
    /** Staff take money from customers. Paying suppliers is the owner's job. */
    public function authorize(): bool
    {
        return ! ($this->filled('purchase_id') || $this->filled('supplier_id')) || $this->user()->isOwner();
    }

    /**
     * Send exactly one of:
     *   sale_id      money in, against one bill
     *   purchase_id  money out, against one bill
     *   customer_id  money in, spread over the customer's oldest bills first
     *   supplier_id  money out, spread over the supplier's oldest bills first
     *
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'sale_id' => ['required_without_all:purchase_id,customer_id,supplier_id', 'prohibits:purchase_id,customer_id,supplier_id', 'nullable', 'integer', CurrentBusiness::exists('sales')],
            'purchase_id' => ['required_without_all:sale_id,customer_id,supplier_id', 'prohibits:sale_id,customer_id,supplier_id', 'nullable', 'integer', CurrentBusiness::exists('purchases')],
            'customer_id' => ['required_without_all:sale_id,purchase_id,supplier_id', 'prohibits:sale_id,purchase_id,supplier_id', 'nullable', 'integer', CurrentBusiness::exists('customers', 'id', softDeletes: true)],
            'supplier_id' => ['required_without_all:sale_id,purchase_id,customer_id', 'prohibits:sale_id,purchase_id,customer_id', 'nullable', 'integer', CurrentBusiness::exists('suppliers', 'id', softDeletes: true)],
            'amount' => ['required', 'integer', 'min:1', 'max:1000000000000000'],
            'method' => ['nullable', 'string', 'max:20'],
            'paid_at' => ['nullable', 'date'],
        ];
    }
}
