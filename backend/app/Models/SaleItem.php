<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// discount, vat_applies and the returned_* columns are not fillable on purpose: SaleService and SaleReturnService set them.
#[Fillable(['sale_id', 'item_id', 'quantity', 'unit_price', 'unit_cost'])]
class SaleItem extends Model
{
    use BelongsToBusiness;

    protected function casts(): array
    {
        return ['vat_applies' => 'boolean'];
    }

    /** What the customer paid for this line, after the share of the bill discount. */
    public function net(): int
    {
        return $this->quantity * $this->unit_price - $this->discount;
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class)->withTrashed();
    }
}
