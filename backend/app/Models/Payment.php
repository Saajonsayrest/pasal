<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['direction', 'sale_id', 'purchase_id', 'amount', 'paid_at', 'method', 'user_id'])]
class Payment extends Model
{
    use BelongsToBusiness;

    protected function casts(): array
    {
        return ['paid_at' => 'datetime'];
    }
}
