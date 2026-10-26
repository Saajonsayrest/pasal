<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

// quantity is not fillable on purpose: stock changes only through StockService.
#[Fillable(['category_id', 'name', 'sku', 'unit', 'vat_applies', 'cost_price', 'sell_price', 'low_stock_at'])]
class Item extends Model
{
    /** @use HasFactory<\Database\Factories\ItemFactory> */
    use BelongsToBusiness, HasFactory, SoftDeletes;

    protected function casts(): array
    {
        return ['vat_applies' => 'boolean'];
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function movements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    public function scopeLowStock(Builder $query): Builder
    {
        return $query->whereColumn('quantity', '<=', 'low_stock_at');
    }
}
