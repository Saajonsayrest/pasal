<?php

namespace App\Console\Commands;

use App\Models\Business;
use App\Models\Category;
use App\Models\Customer;
use App\Models\Expense;
use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use App\Services\PaymentService;
use App\Services\PurchaseService;
use App\Services\SaleReturnService;
use App\Services\SaleService;
use App\Services\StockService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Makes a made-up shop ("Himal Kirana Pasal") with items, customers, bills, credit and expenses,
 * so the phone app and the website have something to show. Fake data only. Local use only.
 * The two logins get random passwords that are printed once.
 */
class DemoShop extends Command
{
    protected $signature = 'pasal:demo-shop';

    protected $description = 'Create a made-up demo shop with an owner and a staff login (local use only).';

    /** name, category, sell price (rupees, VAT included), stock to end with, low level, VAT applies */
    private const ITEMS = [
        ['Basmati rice 5kg', 'Grocery', 1050, 18, 5, true],
        ['Sugar 1kg', 'Grocery', 115, 3, 10, true],
        ['Mustard oil 1L', 'Grocery', 330, 2, 6, true],
        ['Instant noodles', 'Snacks', 25, 140, 40, true],
        ['Red lentils 1kg', 'Grocery', 190, 26, 8, true],
        ['Tea leaves 500g', 'Drinks', 280, 31, 6, true],
        ['Milk 500ml', 'Dairy', 55, 40, 50, false],
        ['Eggs tray of 30', 'Dairy', 520, 9, 3, false],
        ['Biscuits', 'Snacks', 30, 64, 70, true],
        ['Bath soap', 'Personal care', 60, 48, 50, true],
        ['Toothpaste', 'Personal care', 145, 22, 6, true],
        ['Salt 1kg', 'Grocery', 25, 35, 40, true],
    ];

    private const CATEGORIES = [
        'Grocery' => ['rice_bowl', '#e0731a'],
        'Drinks' => ['local_drink', '#2563eb'],
        'Snacks' => ['cookie', '#dc2f55'],
        'Dairy' => ['egg', '#0e8f9e'],
        'Cleaning' => ['cleaning_services', '#7c4ddb'],
        'Personal care' => ['spa', '#1f8a63'],
    ];

    public function handle(StockService $stock, PurchaseService $purchases, SaleService $sales, SaleReturnService $returns, PaymentService $payments): int
    {
        if (app()->isProduction()) {
            $this->error('This command makes fake data. It does not run in production.');

            return self::FAILURE;
        }
        if (Business::where('name', 'Himal Kirana Pasal')->exists()) {
            $this->error('The demo shop already exists. Reset the database first (php artisan migrate:fresh) to make it again.');

            return self::FAILURE;
        }

        mt_srand(42);
        $ownerPassword = Str::password(14, symbols: false);
        $staffPassword = Str::password(14, symbols: false);

        $owner = DB::transaction(function () use ($ownerPassword, $staffPassword) {
            $business = Business::create(['name' => 'Himal Kirana Pasal', 'pan' => '600000001', 'phone' => '01-0000000', 'address' => 'Baneshwor, Kathmandu', 'vat_rate' => 13]);
            $owner = new User(['name' => 'Asha Shrestha', 'email' => 'asha.demo@example.com', 'password' => $ownerPassword]);
            $owner->business_id = $business->id;
            $owner->role = 'owner';
            $owner->save();
            $staff = new User(['name' => 'Bikash K.', 'email' => 'bikash.demo@example.com', 'password' => $staffPassword]);
            $staff->business_id = $business->id;
            $staff->role = 'staff';
            $staff->save();

            return $owner;
        });
        $staff = User::where('email', 'bikash.demo@example.com')->firstOrFail();

        Auth::setUser($owner); // the data belongs to the logged-in person's business
        $this->info('Making the shop ...');

        foreach (self::CATEGORIES as $name => [$icon, $color]) {
            Category::create(['name' => $name, 'icon' => $icon, 'color' => $color]);
        }
        $categories = Category::pluck('id', 'name');

        $items = [];
        foreach (self::ITEMS as [$name, $category, $rupees, , $low, $vat]) {
            $sell = $rupees * 100;
            $cost = (int) round(($vat ? $sell / 1.13 : $sell) * 0.85);
            $items[$name] = Item::create([
                'category_id' => $categories[$category], 'name' => $name, 'unit' => 'pcs', 'vat_applies' => $vat,
                'cost_price' => $cost, 'sell_price' => $sell, 'low_stock_at' => $low,
            ]);
        }

        $supplierNames = ['Everest Traders', 'Sagarmatha Wholesale', 'Annapurna Dairy', 'Koshi Soap Udyog'];
        $suppliers = collect($supplierNames)->mapWithKeys(fn ($n) => [$n => Supplier::create(['name' => $n, 'phone' => '9811'.mt_rand(100000, 999999)])]);

        $customerRows = [
            ['Hari Thapa', '9800000001', null], ['Sita Gurung', '9800000007', null], ['Ram Bahadur KC', '9800000002', 5000000],
            ['Maya Tamang', '9800000003', null], ['Kiran Rai', '9800000004', null], ['Puja Magar', '9800000005', null], ['Dipak Lama', '9800000006', null],
        ];
        $customers = collect($customerRows)->mapWithKeys(fn ($r) => [$r[0] => Customer::create(['name' => $r[0], 'phone' => $r[1], 'credit_limit' => $r[2]])]);

        // Stock comes in with purchases (some of it unpaid, so there is something we owe).
        $bySupplier = [
            'Everest Traders' => ['Basmati rice 5kg', 'Red lentils 1kg', 'Salt 1kg', 'Sugar 1kg'],
            'Sagarmatha Wholesale' => ['Instant noodles', 'Biscuits', 'Tea leaves 500g', 'Mustard oil 1L'],
            'Annapurna Dairy' => ['Milk 500ml', 'Eggs tray of 30'],
            'Koshi Soap Udyog' => ['Bath soap', 'Toothpaste'],
        ];
        $day = 24;
        foreach ($bySupplier as $supplierName => $names) {
            $lines = array_map(fn ($n) => ['item_id' => $items[$n]->id, 'quantity' => $this->target($n) + 60, 'unit_cost' => $items[$n]->cost_price], $names);
            $taxable = array_sum(array_map(fn ($l, $n) => $items[$n]->vat_applies ? $l['quantity'] * $l['unit_cost'] : 0, $lines, $names));
            $vat = (int) round($taxable * 0.13);
            $total = array_sum(array_map(fn ($l) => $l['quantity'] * $l['unit_cost'], $lines)) + $vat;
            $paid = $supplierName === 'Koshi Soap Udyog' ? $total : (int) ($total * 0.6);
            $purchases->create([
                'supplier_id' => $suppliers[$supplierName]->id, 'bill_no' => 'INV-'.(880 + $day), 'bill_date' => now()->subDays($day)->toDateString(),
                'vat_amount' => $vat, 'paid' => $paid, 'method' => 'bank', 'bought_at' => now()->subDays($day)->toDateTimeString(), 'items' => $lines,
            ], $owner->id);
            $day--;
        }

        // About forty bills over three weeks: cash, and credit (udhar) for the regular customers.
        $names = array_keys($items);
        $credit = array_keys($customers->all());
        $price = collect($items)->mapWithKeys(fn ($item) => [$item->id => $item->sell_price])->all();
        for ($i = 0; $i < 40; $i++) {
            $daysAgo = 21 - intdiv($i * 21, 40);
            $seller = $i % 3 === 0 ? $staff : $owner;
            $picked = collect($names)->shuffle()->take(mt_rand(1, 4))->map(fn ($n) => ['item_id' => $items[$n]->id, 'quantity' => mt_rand(1, 3)])->values()->all();
            $total = array_sum(array_map(fn ($l) => $l['quantity'] * $price[$l['item_id']], $picked));
            $onCredit = $i % 4 === 1;
            $customer = $onCredit ? $customers[$credit[$i % count($credit)]] : null;
            Auth::setUser($seller);
            $sales->create([
                'customer_id' => $customer?->id,
                'paid' => $onCredit ? (int) ($total * (($i % 8 === 1) ? 0 : 0.4)) : $total,
                'method' => ['cash', 'qr', 'cash', 'bank'][$i % 4],
                'sold_at' => now()->subDays($daysAgo)->setTime(8 + ($i % 11), ($i * 7) % 60)->toDateTimeString(),
                'items' => $picked,
            ], $seller->id, $seller->isOwner() ? null : 10);
        }
        Auth::setUser($owner);

        // One customer pays back part of the old credit, one bill is partly returned.
        $hari = $customers['Hari Thapa'];
        $paying = \App\Models\Sale::where('customer_id', $hari->id)->whereRaw('total - returned_total - paid > 0')->orderBy('sold_at')->first();
        if ($paying) {
            $payments->record($paying, (int) ($paying->balance() / 2), $owner->id, 'esewa', now()->subDays(3));
        }
        $sale = \App\Models\Sale::with('items')->whereNull('customer_id')->latest('sold_at')->first();
        if ($sale) {
            $returns->process($sale, [['sale_item_id' => $sale->items->first()->id, 'quantity' => 1]], true, 'Wrong size', $owner->id);
        }

        foreach ([['Electricity', 'bills', 185000, 12], ['Shop rent', 'rent', 2500000, 14], ['Tea and snacks', 'other', 42000, 5], ['Transport', 'transport', 95000, 8], ['Staff salary', 'salary', 1800000, 3]] as [$title, $category, $amount, $ago]) {
            Expense::create(['title' => $title, 'category' => $category, 'amount' => $amount, 'spent_at' => now()->subDays($ago), 'user_id' => $owner->id]);
        }

        // Make the shelf match the story: some items low on stock.
        foreach (self::ITEMS as [$name, , , $target]) {
            $item = Item::find($items[$name]->id);
            $diff = $target - $item->quantity;
            if ($diff !== 0) {
                $stock->move($item, $diff, 'adjust', $owner->id, null, 'Demo opening count');
            }
        }

        $this->info('Demo shop ready. Fake data only.');
        $this->table(['Role', 'Email', 'Password (shown once)'], [
            ['Owner', 'asha.demo@example.com', $ownerPassword],
            ['Staff', 'bikash.demo@example.com', $staffPassword],
        ]);

        return self::SUCCESS;
    }

    private function target(string $name): int
    {
        foreach (self::ITEMS as $row) {
            if ($row[0] === $name) {
                return $row[3];
            }
        }

        return 0;
    }
}
