<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBusiness;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

// Nothing is fillable: SaleReturnService is the only writer.
class SaleReturn extends Model
{
    use BelongsToBusiness;

    protected $guarded = ['*'];

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleReturnItem::class);
    }

    protected function casts(): array
    {
        return ['returned_at' => 'datetime', 'restocked' => 'boolean'];
    }
}
