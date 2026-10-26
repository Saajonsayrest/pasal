<?php

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;

/**
 * Adds "WHERE business_id = <the logged-in user's business>" to every query on a model that holds a business's own data.
 *
 * It fails closed: with nobody logged in, it matches no rows at all, so a forgotten
 * login check can never expose another business's data.
 */
class BusinessScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        $businessId = auth()->user()?->business_id;

        if ($businessId) {
            $builder->where($model->getTable().'.business_id', $businessId);
        } else {
            $builder->whereRaw('1 = 0');
        }
    }
}
