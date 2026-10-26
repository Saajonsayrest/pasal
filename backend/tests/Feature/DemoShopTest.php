<?php

use App\Models\Business;
use App\Models\Item;
use App\Models\Sale;
use App\Models\User;
use Illuminate\Support\Facades\Artisan;

it('makes the demo shop with believable numbers', function () {
    expect(Artisan::call('pasal:demo-shop'))->toBe(0);

    $business = Business::where('name', 'Himal Kirana Pasal')->firstOrFail();
    expect(User::where('business_id', $business->id)->count())->toBe(2);

    Auth()->setUser(User::where('email', 'asha.demo@example.com')->firstOrFail());
    expect(Item::count())->toBe(12);
    expect(Item::lowStock()->count())->toBeGreaterThanOrEqual(5);
    expect(Sale::count())->toBe(40);
    expect(Sale::whereRaw('total - returned_total - paid > 0')->count())->toBeGreaterThan(0);

    // Running it twice does not make a second shop.
    expect(Artisan::call('pasal:demo-shop'))->toBe(1);
});
