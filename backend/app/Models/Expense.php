<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['title', 'category', 'amount', 'spent_at', 'user_id'])]
class Expense extends Model
{
    use BelongsToBusiness;

    protected function casts(): array
    {
        return ['spent_at' => 'datetime'];
    }
}
