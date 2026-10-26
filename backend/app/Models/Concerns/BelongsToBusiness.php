<?php

namespace App\Models\Concerns;

use App\Models\Business;
use App\Models\Scopes\BusinessScope;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Put this on every model that holds a business's own data.
 * Reads are filtered by BusinessScope. New rows get the logged-in user's business.
 */
trait BelongsToBusiness
{
    public static function bootBelongsToBusiness(): void
    {
        static::addGlobalScope(new BusinessScope);

        static::creating(function ($model) {
            if (! $model->business_id) {
                $model->business_id = auth()->user()?->business_id;
            }
        });
    }

    public function business(): BelongsTo
    {
        return $this->belongsTo(Business::class);
    }
}
