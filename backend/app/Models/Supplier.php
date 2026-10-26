<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['name', 'phone', 'address', 'pan', 'note'])]
class Supplier extends Model
{
    /** @use HasFactory<\Database\Factories\SupplierFactory> */
    use BelongsToBusiness, HasFactory, SoftDeletes;

    public const WE_OWE_SQL = '(SELECT COALESCE(SUM(p.total - p.paid), 0) FROM purchases p WHERE p.supplier_id = suppliers.id)';

    /** Adds `we_owe` (paisa) and `last_purchase_at` to each supplier in one query. */
    public function scopeWithOwed(Builder $query): Builder
    {
        return $query->select('suppliers.*')
            ->selectRaw(self::WE_OWE_SQL.' AS we_owe')
            ->selectRaw('(SELECT MAX(p.bought_at) FROM purchases p WHERE p.supplier_id = suppliers.id) AS last_purchase_at');
    }
}
