<?php

namespace App\Support;

use App\Models\Business;
use Illuminate\Validation\Rules\Exists;
use Illuminate\Validation\Rules\Unique;
use Illuminate\Validation\Rule;

/**
 * Small helpers for the current business.
 *
 * Laravel's exists and unique validation rules talk to the database directly and skip
 * model scopes. Always build them here, so they check only this business's rows.
 */
class CurrentBusiness
{
    public static function id(): ?int
    {
        return auth()->user()?->business_id;
    }

    /** For factories and tests: the current business, or a brand new one. */
    public static function idOrCreate(): int
    {
        return self::id() ?? Business::factory()->create()->id;
    }

    public static function business(): Business
    {
        return auth()->user()->business;
    }

    public static function exists(string $table, string $column = 'id', bool $softDeletes = false): Exists
    {
        $rule = Rule::exists($table, $column)->where('business_id', self::id());

        return $softDeletes ? $rule->whereNull('deleted_at') : $rule;
    }

    public static function unique(string $table, string $column): Unique
    {
        return Rule::unique($table, $column)->where('business_id', self::id());
    }
}
