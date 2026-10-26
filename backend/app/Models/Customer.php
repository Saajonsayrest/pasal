<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['name', 'phone', 'address', 'pan', 'credit_limit'])]
class Customer extends Model
{
    /** @use HasFactory<\Database\Factories\CustomerFactory> */
    use BelongsToBusiness, HasFactory, SoftDeletes;

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    /** SQL for what this customer still owes: bills less goods sent back less money paid. */
    public const OWES_SQL = '(SELECT COALESCE(SUM(s.total - s.returned_total - s.paid), 0) FROM sales s WHERE s.customer_id = customers.id)';

    /** Adds `owes` (paisa) and `last_sale_at` to each customer in one query. */
    public function scopeWithOwes(Builder $query): Builder
    {
        return $query->select('customers.*')
            ->selectRaw(self::OWES_SQL.' AS owes')
            ->selectRaw('(SELECT MAX(s.sold_at) FROM sales s WHERE s.customer_id = customers.id) AS last_sale_at')
            ->selectRaw('(SELECT MIN(s.sold_at) FROM sales s WHERE s.customer_id = customers.id AND s.total - s.returned_total - s.paid > 0) AS oldest_unpaid_at');
    }
}
