<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Prunable;

// Not business-scoped on purpose: IdempotencyMiddleware reads and writes it with the business id in hand,
// and the daily prune must see every business.
class IdempotencyKey extends Model
{
    use Prunable;

    protected $guarded = ['*'];

    public function prunable(): Builder
    {
        return static::where('created_at', '<', now()->subDay());
    }
}
