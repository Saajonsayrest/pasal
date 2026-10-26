<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Our own bill numbers for sales: S-0001, S-0002 ... one counter per business.
 * Call it inside the transaction that saves the sale. It locks the business row first, so two
 * sales made at the same moment cannot get the same number. Numbers a person typed (any text
 * that is not S- followed by digits) are ignored when counting.
 */
class BillNumber
{
    public static function nextSale(): string
    {
        $businessId = CurrentBusiness::id();

        DB::table('businesses')->where('id', $businessId)->lockForUpdate()->first();

        $last = (int) DB::table('sales')
            ->where('business_id', $businessId)
            ->whereRaw("bill_no ~ '^S-[0-9]{1,12}$'")
            ->selectRaw("COALESCE(MAX(CAST(SUBSTRING(bill_no FROM 3) AS BIGINT)), 0) AS n")
            ->value('n');

        return 'S-'.str_pad((string) ($last + 1), 4, '0', STR_PAD_LEFT);
    }
}
