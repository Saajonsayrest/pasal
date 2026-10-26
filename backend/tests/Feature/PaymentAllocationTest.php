<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\Sale;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

function udharSale(object $test, Customer $customer, int $amount, string $when): int
{
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => $amount]);

    return $test->postJson('/api/v1/sales', [
        'customer_id' => $customer->id, 'paid' => 0, 'sold_at' => $when, 'items' => [['item_id' => $item->id, 'quantity' => 1]],
    ])->assertCreated()->json('data.id');
}

it('pays the oldest bills first and spreads one payment over several bills', function () {
    $customer = Customer::factory()->create();
    $newest = udharSale($this, $customer, 3000, '2026-03-03 10:00:00');
    $oldest = udharSale($this, $customer, 1000, '2026-03-01 10:00:00');
    $middle = udharSale($this, $customer, 2000, '2026-03-02 10:00:00');

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 1500, 'method' => 'esewa'])
        ->assertCreated()
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('data.0.sale_id', $oldest)
        ->assertJsonPath('data.0.amount', 1000)
        ->assertJsonPath('data.1.sale_id', $middle)
        ->assertJsonPath('data.1.amount', 500)
        ->assertJsonPath('owes_left', 4500);

    expect(Sale::find($oldest)->paid)->toBe(1000)
        ->and(Sale::find($middle)->paid)->toBe(500)
        ->and(Sale::find($newest)->paid)->toBe(0);
    $this->assertDatabaseCount('payments', 2);
    $this->assertDatabaseHas('payments', ['sale_id' => $middle, 'method' => 'esewa', 'direction' => 'in']);
});

it('can clear everything a customer owes in one payment', function () {
    $customer = Customer::factory()->create();
    udharSale($this, $customer, 1000, '2026-03-01 10:00:00');
    udharSale($this, $customer, 2000, '2026-03-02 10:00:00');

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 3000])->assertCreated()->assertJsonPath('owes_left', 0);
    $this->getJson("/api/v1/customers/{$customer->id}/ledger")->assertJsonPath('owes', 0);
});

it('refuses a payment bigger than what is owed and saves nothing', function () {
    $customer = Customer::factory()->create();
    udharSale($this, $customer, 1000, '2026-03-01 10:00:00');

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 1001])
        ->assertStatus(422)->assertJsonValidationErrors('amount');
    $this->assertDatabaseCount('payments', 0);
});

it('skips bills that are already paid and bills of other customers', function () {
    $customer = Customer::factory()->create();
    $other = Customer::factory()->create();
    $paidBill = udharSale($this, $customer, 1000, '2026-03-01 10:00:00');
    udharSale($this, $other, 5000, '2026-03-01 11:00:00');
    $open = udharSale($this, $customer, 2000, '2026-03-02 10:00:00');
    $this->postJson('/api/v1/payments', ['sale_id' => $paidBill, 'amount' => 1000])->assertCreated();

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 2000])
        ->assertCreated()->assertJsonCount(1, 'data')->assertJsonPath('data.0.sale_id', $open);
    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 1])->assertStatus(422);
});

it('counts a return before it asks for money', function () {
    $customer = Customer::factory()->create();
    $saleId = udharSale($this, $customer, 1000, '2026-03-01 10:00:00');
    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertCreated();

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 1])->assertStatus(422);
});

it('wants exactly one of sale, purchase, customer or supplier', function () {
    $customer = Customer::factory()->create();

    $this->postJson('/api/v1/payments', ['amount' => 100])->assertStatus(422);
    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'sale_id' => 1, 'amount' => 100])->assertStatus(422);
});

it('pays a supplier oldest purchase first, owner only', function () {
    $supplier = Supplier::factory()->create();
    $item = Item::factory()->create(['quantity' => 0]);
    $buy = fn (string $when, int $cost) => $this->postJson('/api/v1/purchases', [
        'supplier_id' => $supplier->id, 'paid' => 0, 'bought_at' => $when, 'items' => [['item_id' => $item->id, 'quantity' => 1, 'unit_cost' => $cost]],
    ])->assertCreated()->json('data.id');
    $second = $buy('2026-03-02 10:00:00', 2000);
    $first = $buy('2026-03-01 10:00:00', 1000);

    $this->postJson('/api/v1/payments', ['supplier_id' => $supplier->id, 'amount' => 1500])
        ->assertCreated()
        ->assertJsonPath('data.0.purchase_id', $first)
        ->assertJsonPath('data.0.amount', 1000)
        ->assertJsonPath('data.1.purchase_id', $second)
        ->assertJsonPath('data.1.amount', 500)
        ->assertJsonPath('owes_left', 1500);
    $this->assertDatabaseHas('payments', ['purchase_id' => $first, 'direction' => 'out']);

    Sanctum::actingAs(User::factory()->staff()->forBusiness(auth()->user()->business_id)->create());
    $this->postJson('/api/v1/payments', ['supplier_id' => $supplier->id, 'amount' => 100])->assertForbidden();
});

it('lets staff take a customer payment', function () {
    $customer = Customer::factory()->create();
    udharSale($this, $customer, 1000, '2026-03-01 10:00:00');
    Sanctum::actingAs(User::factory()->staff()->forBusiness($customer->business_id)->create());

    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 400])->assertCreated();
});

it('will not touch another shop\'s customer', function () {
    $mine = Customer::factory()->create();
    udharSale($this, $mine, 1000, '2026-03-01 10:00:00');
    $stranger = User::factory()->create();
    Sanctum::actingAs($stranger);

    $this->postJson('/api/v1/payments', ['customer_id' => $mine->id, 'amount' => 100])->assertStatus(422)->assertJsonValidationErrors('customer_id');
});
