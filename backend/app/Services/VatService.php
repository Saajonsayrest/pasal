<?php

namespace App\Services;

use App\Models\Purchase;
use App\Models\Sale;
use App\Models\SaleReturn;
use App\Models\VatFiling;
use App\Support\CurrentBusiness;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;

/**
 * Works out one VAT period from the sales and purchases we already recorded.
 *
 *   net = VAT collected on sales - VAT paid on purchases - credit carried from last period
 *   net > 0  -> pay it
 *   net <= 0 -> pay nothing, carry the extra to the next period (VAT Act 2052, s.24)
 */
class VatService
{
    /**
     * @return array<string, int|string|null>
     */
    public function preview(CarbonInterface $from, CarbonInterface $to, int $openingCarry = 0): array
    {
        $start = $from->copy()->startOfDay();
        $end = $to->copy()->endOfDay();

        $sales = Sale::whereBetween('sold_at', [$start, $end])
            ->selectRaw('COALESCE(SUM(taxable_amount),0) AS taxable, COALESCE(SUM(exempt_amount),0) AS exempt, COALESCE(SUM(vat_amount),0) AS vat, COUNT(*) AS bills')
            ->first();

        // A return or cancel is a credit note: it lowers the VAT of the month it happened in,
        // never the month of the original bill (that month may already be filed).
        $returns = SaleReturn::whereBetween('returned_at', [$start, $end])
            ->selectRaw('COALESCE(SUM(taxable_amount),0) AS taxable, COALESCE(SUM(exempt_amount),0) AS exempt, COALESCE(SUM(vat_amount),0) AS vat')
            ->first();

        // Input VAT is claimed on the supplier's bill date. If we did not record it, we use the purchase date.
        $purchases = Purchase::where('vat_amount', '>', 0)
            ->whereRaw('COALESCE(bill_date, bought_at::date) BETWEEN ? AND ?', [$start->toDateString(), $end->toDateString()])
            ->selectRaw('COALESCE(SUM(total - vat_amount),0) AS taxable, COALESCE(SUM(vat_amount),0) AS vat, COUNT(*) AS bills')
            ->first();

        $previous = VatFiling::where('period_to', '<', $start->toDateString())->orderByDesc('period_to')->first();
        $carryIn = $previous ? (int) $previous->carry_out : $openingCarry;

        $output = (int) $sales->vat - (int) $returns->vat;
        $input = (int) $purchases->vat;
        $net = $output - $input - $carryIn;

        return [
            'period_from' => $start->toDateString(),
            'period_to' => $end->toDateString(),
            'due_date' => Carbon::parse($end)->addDays((int) config('pasal.vat_due_days'))->toDateString(),
            'vat_rate' => (float) CurrentBusiness::business()->vat_rate,
            'sales_bills' => (int) $sales->bills,
            'sales_taxable' => (int) $sales->taxable - (int) $returns->taxable,
            'sales_exempt' => (int) $sales->exempt - (int) $returns->exempt,
            'output_vat' => $output,
            'purchase_bills_with_vat' => (int) $purchases->bills,
            'purchases_taxable' => (int) $purchases->taxable,
            'input_vat' => $input,
            'carry_in' => $carryIn,
            'payable' => max($net, 0),
            'carry_out' => max(-$net, 0),
            'carry_in_source' => $previous ? "filing {$previous->period}" : 'opening value you typed (0 if none)',
        ];
    }
}
