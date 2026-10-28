<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

/** Builds one shop with money in and out on three days. */
function busyShop(object $test): void
{
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $customer = Customer::factory()->create();
    $supplier = Supplier::factory()->create();

    // Day 1: cash sale 5000, udhar sale 2000 with nothing paid.
    $test->postJson('/api/v1/sales', ['paid' => 5000, 'sold_at' => '2026-04-01 10:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 5]]])->assertCreated();
    $udhar = $test->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => 0, 'sold_at' => '2026-04-01 11:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->json('data.id');

    // Day 2: customer pays 1500 by eSewa, shop pays supplier 3000 and an expense of 400.
    $test->postJson('/api/v1/payments', ['sale_id' => $udhar, 'amount' => 1500, 'method' => 'esewa', 'paid_at' => '2026-04-02 10:00:00'])->assertCreated();
    $purchase = $test->postJson('/api/v1/purchases', ['supplier_id' => $supplier->id, 'paid' => 0, 'bought_at' => '2026-04-02 09:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 3, 'unit_cost' => 1000]]])->json('data.id');
    $test->postJson('/api/v1/payments', ['purchase_id' => $purchase, 'amount' => 3000, 'paid_at' => '2026-04-02 11:00:00'])->assertCreated();
    $test->postJson('/api/v1/expenses', ['title' => 'Electricity', 'amount' => 400, 'spent_at' => '2026-04-02 12:00:00'])->assertCreated();
}

it('adds up money in and out with a running balance', function () {
    busyShop($this);

    $this->getJson('/api/v1/cash-book?from=2026-04-01&to=2026-04-30')
        ->assertOk()
        ->assertJsonPath('opening_balance', 0)
        ->assertJsonPath('money_in', 6500)
        ->assertJsonPath('money_out', 3400)
        ->assertJsonPath('closing_balance', 3100)
        ->assertJsonPath('meta.total', 4)
        ->assertJsonPath('data.0.kind', 'payment_in')
        ->assertJsonPath('data.0.balance', 5000)
        ->assertJsonPath('data.1.amount', 1500)
        ->assertJsonPath('data.1.method', 'esewa')
        ->assertJsonPath('data.2.kind', 'payment_out')
        ->assertJsonPath('data.2.amount', -3000)
        ->assertJsonPath('data.3.kind', 'expense')
        ->assertJsonPath('data.3.label', 'Electricity')
        ->assertJsonPath('data.3.balance', 3100);
});

it('starts a later range with what the earlier days left', function () {
    busyShop($this);

    $this->getJson('/api/v1/cash-book?from=2026-04-02&to=2026-04-02')
        ->assertOk()
        ->assertJsonPath('opening_balance', 5000)
        ->assertJsonPath('money_in', 1500)
        ->assertJsonPath('money_out', 3400)
        ->assertJsonPath('closing_balance', 3100)
        ->assertJsonPath('data.0.balance', 6500); // running balance continues from the earlier day
});

it('cuts the day at midnight in Nepal, not midnight UTC', function () {
    // 19:00 UTC on 1 April is 00:45 on 2 April in Nepal (UTC+5:45).
    $this->postJson('/api/v1/expenses', ['title' => 'Late rent', 'amount' => 700, 'spent_at' => '2026-04-01 19:00:00'])->assertCreated();

    $this->getJson('/api/v1/cash-book?from=2026-04-01&to=2026-04-01')->assertOk()->assertJsonPath('meta.total', 0);
    $this->getJson('/api/v1/cash-book?from=2026-04-02&to=2026-04-02')->assertOk()
        ->assertJsonPath('meta.total', 1)
        ->assertJsonPath('money_out', 700);
    $this->getJson('/api/v1/reports/summary?from=2026-04-02&to=2026-04-02')->assertOk()
        ->assertJsonPath('from', '2026-04-02')
        ->assertJsonPath('expenses_total', 700);
});

it('counts a refund as money out', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $saleId = $this->postJson('/api/v1/sales', ['paid' => 3000, 'sold_at' => '2026-04-01 10:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 3]]])->json('data.id');
    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertCreated();
    $today = now()->toDateString();

    $this->getJson("/api/v1/cash-book?from=2026-04-01&to={$today}")
        ->assertOk()->assertJsonPath('closing_balance', 0)->assertJsonPath('money_in', 3000)->assertJsonPath('money_out', 3000)
        ->assertJsonPath('data.1.kind', 'refund');
});

it('pages the book and keeps the balance right on page two', function () {
    busyShop($this);

    $this->getJson('/api/v1/cash-book?from=2026-04-01&to=2026-04-30&per_page=3&page=2')
        ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.balance', 3100)->assertJsonPath('meta.total', 4);
});

it('never shows another shop\'s money', function () {
    busyShop($this);
    Sanctum::actingAs(User::factory()->create());

    $this->getJson('/api/v1/cash-book?from=2026-04-01&to=2026-04-30')
        ->assertOk()->assertJsonPath('money_in', 0)->assertJsonPath('closing_balance', 0)->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/payments')->assertOk()->assertJsonCount(0, 'data');
});

it('needs a date range and the owner', function () {
    $this->getJson('/api/v1/cash-book')->assertStatus(422);
    $this->getJson('/api/v1/cash-book?from=2026-04-05&to=2026-04-01')->assertStatus(422);

    Sanctum::actingAs(User::factory()->staff()->forBusiness(auth()->user()->business_id)->create());
    $this->getJson('/api/v1/cash-book?from=2026-04-01&to=2026-04-30')->assertForbidden();
    $this->getJson('/api/v1/payments')->assertForbidden();
});

it('lists payments with filters and who paid', function () {
    busyShop($this);

    $this->getJson('/api/v1/payments')->assertOk()->assertJsonCount(3, 'data')
        ->assertJsonStructure(['data' => [['id', 'direction', 'sale_id', 'purchase_id', 'amount', 'method', 'paid_at', 'party']], 'links', 'meta']);

    $this->getJson('/api/v1/payments?direction=out')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.amount', 3000);
    $this->getJson('/api/v1/payments?method=esewa')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.amount', 1500);
    $this->getJson('/api/v1/payments?from=2026-04-02&to=2026-04-02')->assertOk()->assertJsonCount(2, 'data');
    $this->getJson('/api/v1/payments?direction=bogus')->assertStatus(422);
});

it('filters payments by customer or supplier', function () {
    busyShop($this);
    $customer = Customer::first();
    $supplier = Supplier::first();

    $this->getJson("/api/v1/payments?customer_id={$customer->id}")->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.party', $customer->name);
    $this->getJson("/api/v1/payments?supplier_id={$supplier->id}")->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.party', $supplier->name);
});
