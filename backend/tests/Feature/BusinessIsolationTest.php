<?php

use App\Models\Category;
use App\Models\Customer;
use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

/**
 * Two separate shops. Everything B owns is created while B is logged in.
 * Then we log in as A and try to reach it in every way we can think of.
 *
 * @return array{a: User, b: User, itemB: Item, customerB: Customer, supplierB: Supplier, saleB: int}
 */
function twoShops(object $test): array
{
    $a = User::factory()->create();
    $b = User::factory()->create();

    Sanctum::actingAs($b);
    $itemB = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300, 'sku' => 'SAME-SKU']);
    $customerB = Customer::factory()->create();
    $supplierB = Supplier::factory()->create();
    $saleB = $test->postJson('/api/v1/sales', [
        'customer_id' => $customerB->id, 'paid' => 0, 'items' => [['item_id' => $itemB->id, 'quantity' => 2]],
    ])->assertCreated()->json('data.id');

    Sanctum::actingAs($a);

    return compact('a', 'b', 'itemB', 'customerB', 'supplierB', 'saleB');
}

it('lists only your own records', function () {
    $s = twoShops($this);
    Item::factory()->count(2)->create();

    $this->getJson('/api/v1/items')->assertOk()->assertJsonCount(2, 'data');
    $this->getJson('/api/v1/customers')->assertOk()->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/sales')->assertOk()->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/suppliers')->assertOk()->assertJsonCount(0, 'data');
});

it('answers 404 for another shop record, on read, update and delete', function () {
    $s = twoShops($this);
    $id = $s['itemB']->id;

    $this->getJson("/api/v1/items/{$id}")->assertNotFound();
    $this->putJson("/api/v1/items/{$id}", ['name' => 'Hacked', 'sku' => 'X1', 'cost_price' => 1, 'sell_price' => 1])->assertNotFound();
    $this->deleteJson("/api/v1/items/{$id}")->assertNotFound();
    $this->getJson("/api/v1/sales/{$s['saleB']}")->assertNotFound();
    $this->getJson("/api/v1/customers/{$s['customerB']->id}")->assertNotFound();
    $this->getJson("/api/v1/customers/{$s['customerB']->id}/ledger")->assertNotFound();
    $this->getJson("/api/v1/suppliers/{$s['supplierB']->id}/ledger")->assertNotFound();

    expect(Item::withoutGlobalScopes()->find($id)->name)->not->toBe('Hacked');
});

it('refuses to use another shop item, customer or supplier inside your own sale or purchase', function () {
    $s = twoShops($this);
    $mine = Item::factory()->create(['quantity' => 5]);

    $this->postJson('/api/v1/sales', ['paid' => 0, 'customer_id' => $s['customerB']->id, 'items' => [['item_id' => $mine->id, 'quantity' => 1]]])
        ->assertStatus(422)->assertJsonValidationErrors('customer_id');

    $this->postJson('/api/v1/sales', ['paid' => 100, 'items' => [['item_id' => $s['itemB']->id, 'quantity' => 1]]])
        ->assertStatus(422)->assertJsonValidationErrors('items.0.item_id');

    $this->postJson('/api/v1/purchases', ['supplier_id' => $s['supplierB']->id, 'items' => [['item_id' => $mine->id, 'quantity' => 1, 'unit_cost' => 5]]])
        ->assertStatus(422)->assertJsonValidationErrors('supplier_id');

    Sanctum::actingAs($s['b']);
    $categoryB = Category::factory()->create();
    Sanctum::actingAs($s['a']);

    $this->postJson('/api/v1/items', ['name' => 'X', 'sku' => 'NEW-1', 'cost_price' => 1, 'sell_price' => 2, 'category_id' => $categoryB->id])
        ->assertStatus(422)->assertJsonValidationErrors('category_id');
});

it('refuses payments and stock changes on another shop record', function () {
    $s = twoShops($this);

    $this->postJson('/api/v1/payments', ['sale_id' => $s['saleB'], 'amount' => 100])
        ->assertStatus(422)->assertJsonValidationErrors('sale_id');

    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $s['itemB']->id, 'change' => -5, 'note' => 'steal'])
        ->assertStatus(422)->assertJsonValidationErrors('item_id');

    $b = Item::withoutGlobalScopes()->find($s['itemB']->id);
    expect($b->quantity)->toBe(8); // 10 minus the 2 B sold, untouched by A
});

it('ignores a business_id sent by the client', function () {
    $s = twoShops($this);

    $id = $this->postJson('/api/v1/items', [
        'name' => 'Mine', 'sku' => 'MINE-1', 'cost_price' => 1, 'sell_price' => 2, 'business_id' => $s['b']->business_id,
    ])->assertCreated()->json('data.id');

    expect(Item::withoutGlobalScopes()->find($id)->business_id)->toBe($s['a']->business_id);
});

it('lets two shops use the same SKU and the same category name', function () {
    $s = twoShops($this);

    $this->postJson('/api/v1/items', ['name' => 'Rice', 'sku' => 'SAME-SKU', 'cost_price' => 1, 'sell_price' => 2])->assertCreated();

    Sanctum::actingAs($s['b']);
    $this->postJson('/api/v1/categories', ['name' => 'Grocery'])->assertCreated();
    Sanctum::actingAs($s['a']);
    $this->postJson('/api/v1/categories', ['name' => 'Grocery'])->assertCreated();
    $this->postJson('/api/v1/categories', ['name' => 'Grocery'])->assertStatus(422);
});

it('counts only your own money in reports and VAT', function () {
    $s = twoShops($this);
    $today = now()->toDateString();

    $this->getJson("/api/v1/reports/summary?from={$today}&to={$today}")->assertOk()
        ->assertJsonPath('sales_total', 0)->assertJsonPath('owed_to_us', 0)->assertJsonPath('stock_value', 0);

    $this->getJson("/api/v1/vat/preview?from={$today}&to={$today}")->assertOk()
        ->assertJsonPath('output_vat', 0)->assertJsonPath('sales_bills', 0);
});

it('lets two shops keep the same VAT period label', function () {
    $s = twoShops($this);
    $today = now()->toDateString();

    Sanctum::actingAs($s['b']);
    $this->postJson('/api/v1/vat/filings', ['period' => '2083-07', 'from' => $today, 'to' => $today])->assertCreated();

    Sanctum::actingAs($s['a']);
    $this->postJson('/api/v1/vat/filings', ['period' => '2083-07', 'from' => $today, 'to' => $today])->assertCreated();
    $this->getJson('/api/v1/vat/filings')->assertJsonCount(1, 'data');
});

it('uses the VAT rate of your own business', function () {
    $s = twoShops($this);
    $this->patchJson('/api/v1/business', ['vat_rate' => 5])->assertOk()->assertJsonPath('data.vat_rate', 5);

    $item = Item::factory()->create(['quantity' => 5, 'sell_price' => 10500]);

    $this->postJson('/api/v1/sales', ['paid' => 10500, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertCreated()
        ->assertJsonPath('data.vat_rate', 5)
        ->assertJsonPath('data.vat_amount', 500);

    expect((float) $s['b']->business()->first()->vat_rate)->toBe(13.0);
});

it('fails closed: with nobody logged in a query returns nothing', function () {
    $s = twoShops($this);
    Item::factory()->create();

    $this->app['auth']->forgetGuards();

    expect(Item::count())->toBe(0);
    expect(Item::withoutGlobalScopes()->count())->toBeGreaterThan(0);
});

it('only lets the owner see and manage users of their own business', function () {
    $s = twoShops($this);
    User::factory()->staff()->forBusiness($s['a']->business_id)->create();

    $this->getJson('/api/v1/users')->assertOk()->assertJsonCount(2, 'data');
    $this->deleteJson("/api/v1/users/{$s['b']->id}")->assertNotFound();
    $this->patchJson("/api/v1/users/{$s['b']->id}", ['name' => 'Hacked'])->assertNotFound();

    expect($s['b']->fresh()->name)->not->toBe('Hacked');
});

it('lets an owner add a staff login who can sign in', function () {
    twoShops($this);

    $this->postJson('/api/v1/users', ['name' => 'Sita', 'email' => 'sita@example.com', 'password' => 'long-enough-pass', 'role' => 'staff'])
        ->assertCreated()->assertJsonPath('data.role', 'staff');

    $this->postJson('/api/v1/login', ['email' => 'sita@example.com', 'password' => 'long-enough-pass'])
        ->assertOk()->assertJsonPath('user.role', 'staff');

    $this->postJson('/api/v1/users', ['name' => 'Dup', 'email' => 'sita@example.com', 'password' => 'long-enough-pass', 'role' => 'staff'])
        ->assertStatus(422)->assertJsonValidationErrors('email');

    $this->postJson('/api/v1/users', ['name' => 'Weak', 'email' => 'weak@example.com', 'password' => 'short', 'role' => 'staff'])
        ->assertStatus(422)->assertJsonValidationErrors('password');
});

it('stops the owner from deleting or demoting themselves', function () {
    $s = twoShops($this);

    $this->deleteJson("/api/v1/users/{$s['a']->id}")->assertStatus(422);
    $this->patchJson("/api/v1/users/{$s['a']->id}", ['role' => 'staff'])->assertStatus(422)->assertJsonValidationErrors('role');
});

it('signs a user out everywhere when the owner changes their password', function () {
    $s = twoShops($this);
    $staff = User::factory()->staff()->forBusiness($s['a']->business_id)->create();
    $staff->createToken('phone');

    $this->patchJson("/api/v1/users/{$staff->id}", ['password' => 'brand-new-password'])->assertOk();

    expect($staff->tokens()->count())->toBe(0);
});

it('limits staff to counter work', function () {
    $a = User::factory()->create();
    $staff = User::factory()->staff()->forBusiness($a->business_id)->create();

    Sanctum::actingAs($a);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000, 'cost_price' => 3000]);
    $supplier = Supplier::factory()->create();

    Sanctum::actingAs($staff);

    // Allowed
    $this->getJson('/api/v1/items')->assertOk()->assertJsonPath('data.0.cost_price', null)->assertJsonPath('data.0.sell_price', 5000);
    $this->postJson('/api/v1/customers', ['name' => 'Walk Ram'])->assertCreated();
    $this->postJson('/api/v1/sales', ['paid' => 5000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
    $this->getJson('/api/v1/business')->assertOk();
    $this->getJson('/api/v1/me')->assertOk()->assertJsonPath('role', 'staff');

    // Not allowed
    $this->postJson('/api/v1/items', ['name' => 'X', 'sku' => 'S', 'cost_price' => 1, 'sell_price' => 2])->assertForbidden();
    $this->putJson("/api/v1/items/{$item->id}", ['name' => 'X', 'sku' => 'S', 'cost_price' => 1, 'sell_price' => 2])->assertForbidden();
    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => 5, 'note' => 'x'])->assertForbidden();
    $this->getJson('/api/v1/suppliers')->assertForbidden();
    $this->getJson("/api/v1/suppliers/{$supplier->id}/ledger")->assertForbidden();
    $this->getJson('/api/v1/purchases')->assertForbidden();
    $this->postJson('/api/v1/purchases', [])->assertForbidden();
    $this->getJson('/api/v1/expenses')->assertForbidden();
    $this->getJson('/api/v1/reports/summary?from=2026-01-01&to=2026-01-02')->assertForbidden();
    $this->getJson('/api/v1/vat/preview?from=2026-01-01&to=2026-01-02')->assertForbidden();
    $this->getJson('/api/v1/vat/filings')->assertForbidden();
    $this->getJson('/api/v1/users')->assertForbidden();
    $this->patchJson('/api/v1/business', ['name' => 'Mine now'])->assertForbidden();
    $this->postJson('/api/v1/payments', ['purchase_id' => 1, 'amount' => 5])->assertForbidden();
});

it('lets staff take a customer payment on a sale', function () {
    $a = User::factory()->create();
    $staff = User::factory()->staff()->forBusiness($a->business_id)->create();
    Sanctum::actingAs($a);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $customer = Customer::factory()->create();
    $saleId = $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->json('data.id');

    Sanctum::actingAs($staff);
    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 5000])->assertCreated()->assertJsonPath('balance_left', 0);
});

it('changes your own password and keeps only this device signed in', function () {
    $user = User::factory()->create(['password' => 'old-password-1']);
    $phone = $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'old-password-1'])->json('token');
    $laptop = $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'old-password-1'])->json('token');

    $this->withToken($phone)->postJson('/api/v1/me/password', ['current_password' => 'wrong', 'password' => 'new-password-22'])
        ->assertStatus(422)->assertJsonValidationErrors('current_password');

    $this->withToken($phone)->postJson('/api/v1/me/password', ['current_password' => 'old-password-1', 'password' => 'new-password-22'])
        ->assertOk();

    expect($user->tokens()->count())->toBe(1);
    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'new-password-22'])->assertOk();
});

it('logs out on all devices', function () {
    $user = User::factory()->create(['password' => 'old-password-1']);
    $user->createToken('a');
    $token = $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'old-password-1'])->json('token');

    $this->withToken($token)->postJson('/api/v1/logout-all')->assertOk();

    expect($user->tokens()->count())->toBe(0);
});
