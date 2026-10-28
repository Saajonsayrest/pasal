<?php

namespace App\Support;

use Illuminate\Support\Carbon;

/**
 * A shop thinks in Nepal days (UTC+5:45), but timestamps are stored in UTC.
 * These turn a Nepal calendar date into the exact UTC moment the day starts or ends.
 */
final class ShopDay
{
    public const ZONE = 'Asia/Kathmandu';

    /** First moment of the Nepal day, as UTC. */
    public static function start(string $date): Carbon
    {
        return Carbon::parse($date, self::ZONE)->startOfDay()->utc();
    }

    /** Last moment of the Nepal day, as UTC. */
    public static function end(string $date): Carbon
    {
        return Carbon::parse($date, self::ZONE)->endOfDay()->utc();
    }

    /** SQL: a stored UTC timestamp column written as Nepal shop time. */
    public static function local(string $column): string
    {
        return "((({$column}) AT TIME ZONE 'UTC') AT TIME ZONE '".self::ZONE."')";
    }
}
