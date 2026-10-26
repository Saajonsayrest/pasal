<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VatFilingResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'period' => $this->period,
            'period_from' => $this->period_from?->toDateString(),
            'period_to' => $this->period_to?->toDateString(),
            'source' => $this->source,
            'sales_taxable' => $this->sales_taxable,
            'sales_exempt' => $this->sales_exempt,
            'output_vat' => $this->output_vat,
            'purchases_taxable' => $this->purchases_taxable,
            'input_vat' => $this->input_vat,
            'carry_in' => $this->carry_in,
            'payable' => $this->payable,
            'carry_out' => $this->carry_out,
            'filed_on' => $this->filed_on?->toDateString(),
            'paid_amount' => $this->paid_amount,
            'paid_on' => $this->paid_on?->toDateString(),
            'receipt_no' => $this->receipt_no,
            'note' => $this->note,
        ];
    }
}
