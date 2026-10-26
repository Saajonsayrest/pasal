<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'period', 'period_from', 'period_to', 'source', 'sales_taxable', 'sales_exempt', 'output_vat',
    'purchases_taxable', 'input_vat', 'carry_in', 'payable', 'carry_out',
    'filed_on', 'paid_amount', 'paid_on', 'receipt_no', 'note', 'user_id',
])]
class VatFiling extends Model
{
    use BelongsToBusiness;

    protected function casts(): array
    {
        return [
            'period_from' => 'date:Y-m-d',
            'period_to' => 'date:Y-m-d',
            'filed_on' => 'date:Y-m-d',
            'paid_on' => 'date:Y-m-d',
        ];
    }
}
