<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

// paid, discount, returned_total and cancelled_at are not fillable on purpose:
// only PaymentService, SaleService and SaleReturnService change them.
#[Fillable(['customer_id', 'total', 'sold_at', 'user_id', 'note', 'bill_no'])]
class Sale extends Model
{
    use BelongsToBusiness;

    public function items(): HasMany
    {
        return $this->hasMany(SaleItem::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function returns(): HasMany
    {
        return $this->hasMany(SaleReturn::class);
    }

    /** What the customer still owes: the total, less goods sent back, less money paid. */
    public function balance(): int
    {
        return $this->total - $this->returned_total - $this->paid;
    }

    protected function casts(): array
    {
        return ['sold_at' => 'datetime', 'cancelled_at' => 'datetime'];
    }
}
