<?php

use App\Models\Customer;
use App\Models\Expense;
use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

it('sells items: lowers stock, records total and the paid payment', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000, 'cost_price' => 3000]);

    $this->postJson('/api/v1/sales', ['paid' => 10000, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])
        ->assertCreated()
        ->assertJsonPath('data.total', 10000)
        ->assertJsonPath('data.paid', 10000);

    expect($item->refresh()->quantity)->toBe(8);
    $this->assertDatabaseHas('payments', ['direction' => 'in', 'amount' => 10000]);
    $this->assertDatabaseHas('stock_movements', ['item_id' => $item->id, 'change' => -2, 'reason' => 'sale']);
});

it('returns the sale shape written in docs/api-reference.md', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300]);

    $id = $this->postJson('/api/v1/sales', ['paid' => 5000, 'customer_id' => Customer::factory()->create()->id, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertCreated()->json('data.id');

    $this->getJson("/api/v1/sales/{$id}")
        ->assertOk()
        ->assertJsonStructure(['data' => [
            'id', 'bill_no', 'customer_id', 'customer' => ['id', 'name'], 'total', 'paid', 'balance', 'vat_rate',
            'taxable_amount', 'vat_amount', 'exempt_amount', 'sold_at', 'note',
            'items' => [['item_id', 'item_name', 'quantity', 'unit_price', 'line_total']],
            'payments' => [['id', 'direction', 'sale_id', 'purchase_id', 'amount', 'method', 'paid_at']],
        ]])
        ->assertJsonPath('data.vat_amount', 1300)
        ->assertJsonPath('data.balance', 6300);

    $this->getJson('/api/v1/sales')->assertOk()->assertJsonStructure(['data', 'links', 'meta' => ['current_page', 'per_page', 'total']]);
});

it('shows a walk-in sale with customer null', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    $this->postJson('/api/v1/sales', ['paid' => 5000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertCreated()
        ->assertJsonPath('data.customer', null);
});

it('allows udhar for a named customer and tracks what they owe', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $customer = Customer::factory()->create();

    $this->postJson('/api/v1/sales', [
        'customer_id' => $customer->id, 'paid' => 2000, 'items' => [['item_id' => $item->id, 'quantity' => 2]],
    ])->assertCreated();

    $this->getJson("/api/v1/customers/{$customer->id}/ledger")
        ->assertOk()
        ->assertJsonPath('owes', 8000);
});

it('refuses an unpaid sale without a customer', function () {
    $item = Item::factory()->create(['quantity' => 10]);

    $this->postJson('/api/v1/sales', ['paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertStatus(422)
        ->assertJsonValidationErrors('customer_id');
});

it('saves nothing when one line has not enough stock', function () {
    $a = Item::factory()->create(['quantity' => 5]);
    $b = Item::factory()->create(['quantity' => 1]);

    $this->postJson('/api/v1/sales', [
        'paid' => 0, 'customer_id' => Customer::factory()->create()->id,
        'items' => [['item_id' => $a->id, 'quantity' => 2], ['item_id' => $b->id, 'quantity' => 5]],
    ])->assertStatus(422);

    expect($a->refresh()->quantity)->toBe(5);
    $this->assertDatabaseCount('sales', 0);
    $this->assertDatabaseCount('stock_movements', 0);
});

it('takes a later payment and refuses to overpay', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $customer = Customer::factory()->create();
    $saleId = $this->postJson('/api/v1/sales', [
        'customer_id' => $customer->id, 'items' => [['item_id' => $item->id, 'quantity' => 2]],
    ])->json('data.id');

    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 6000])
        ->assertCreated()
        ->assertJsonPath('balance_left', 4000);

    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 4001])
        ->assertStatus(422)
        ->assertJsonValidationErrors('amount');
});

it('buys stock from a supplier and tracks what we owe', function () {
    $item = Item::factory()->create(['quantity' => 1]);
    $supplier = Supplier::factory()->create();

    $this->postJson('/api/v1/purchases', [
        'supplier_id' => $supplier->id, 'paid' => 10000,
        'items' => [['item_id' => $item->id, 'quantity' => 10, 'unit_cost' => 2500]],
    ])->assertCreated()->assertJsonPath('data.total', 25000);

    expect($item->refresh()->quantity)->toBe(11);
    expect($item->cost_price)->toBe(2500);

    $this->getJson("/api/v1/suppliers/{$supplier->id}/ledger")->assertOk()->assertJsonPath('we_owe', 15000);
});

it('rejects a payment that names both a sale and a purchase', function () {
    $this->postJson('/api/v1/payments', ['sale_id' => 1, 'purchase_id' => 1, 'amount' => 5])
        ->assertStatus(422);
});

it('reports profit as sales minus VAT minus cost minus expenses', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000, 'cost_price' => 3000]);
    $this->postJson('/api/v1/sales', ['paid' => 10000, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->assertCreated();
    Expense::create(['title' => 'Electricity', 'amount' => 1500, 'spent_at' => now()]);

    $today = now()->toDateString();

    $this->getJson("/api/v1/reports/summary?from={$today}&to={$today}")
        ->assertOk()
        ->assertJsonPath('sales_total', 10000)
        ->assertJsonPath('cost_of_goods', 6000)
        ->assertJsonPath('expenses_total', 1500)
        ->assertJsonPath('vat_collected', 1150)
        ->assertJsonPath('profit', 1350)
        ->assertJsonPath('stock_value', 24000);
});
