<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

it('lowers the total by the discount and shows it on the lines', function () {
    $a = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $b = Item::factory()->create(['quantity' => 10, 'sell_price' => 3000]);

    $response = $this->postJson('/api/v1/sales', [
        'paid' => 11700, 'discount' => 1300,
        'items' => [['item_id' => $a->id, 'quantity' => 2], ['item_id' => $b->id, 'quantity' => 1]],
    ])->assertCreated()
        ->assertJsonPath('data.subtotal', 13000)
        ->assertJsonPath('data.discount', 1300)
        ->assertJsonPath('data.total', 11700)
        ->assertJsonPath('data.balance', 0)
        ->assertJsonPath('data.vat_amount', (int) round(11700 * 13 / 113));

    expect(collect($response->json('data.items'))->sum('discount'))->toBe(1300)
        ->and(collect($response->json('data.items'))->sum('line_total'))->toBe(11700);
});

it('splits an odd discount so the line shares always add up', function () {
    $items = Item::factory()->count(3)->create(['quantity' => 10, 'sell_price' => 100]);

    $this->postJson('/api/v1/sales', [
        'paid' => 200, 'discount' => 100,
        'items' => $items->map(fn ($i) => ['item_id' => $i->id, 'quantity' => 1])->all(),
    ])->assertCreated()->assertJsonPath('data.total', 200);

    expect((int) SaleItem::sum('discount'))->toBe(100);
});

it('refuses a discount bigger than the bill', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    $this->postJson('/api/v1/sales', ['paid' => 0, 'discount' => 5001, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertStatus(422)->assertJsonValidationErrors('discount');
});

it('keeps VAT out of the lines that carry none, after the discount', function () {
    $vat = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300, 'vat_applies' => true]);
    $plain = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300, 'vat_applies' => false]);

    // Discount 2260 is split half and half: 1130 off each line.
    $this->postJson('/api/v1/sales', [
        'paid' => 20340, 'discount' => 2260,
        'items' => [['item_id' => $vat->id, 'quantity' => 1], ['item_id' => $plain->id, 'quantity' => 1]],
    ])->assertCreated()
        ->assertJsonPath('data.total', 20340)
        ->assertJsonPath('data.vat_amount', 1170) // 10170 * 13 / 113
        ->assertJsonPath('data.taxable_amount', 9000)
        ->assertJsonPath('data.exempt_amount', 10170);
});

it('lets staff give a small discount and sends a big one to the owner', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    Sanctum::actingAs(User::factory()->staff()->forBusiness($item->business_id)->create());
    $sell = fn (int $discount) => $this->postJson('/api/v1/sales', ['paid' => 1000 - $discount, 'discount' => $discount, 'items' => [['item_id' => $item->id, 'quantity' => 1]]]);

    $sell(100)->assertCreated()->assertJsonPath('data.total', 900); // exactly 10%
    $sell(101)->assertStatus(422)->assertJsonValidationErrors('discount');

    Sanctum::actingAs(User::factory()->forBusiness($item->business_id)->create());
    $sell(900)->assertCreated()->assertJsonPath('data.total', 100);
});

it('stops udhar past the credit limit', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $customer = Customer::factory()->create(['credit_limit' => 5000]);
    $sell = fn (int $qty) => $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => $qty]]]);

    $sell(6)->assertStatus(422)->assertJsonValidationErrors('customer_id');
    $sell(5)->assertCreated();
    $sell(1)->assertStatus(422)->assertJsonValidationErrors('customer_id');

    expect($item->refresh()->quantity)->toBe(5);
});

it('lets a customer with no limit buy on udhar and a customer with limit 0 buy only for cash', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $free = Customer::factory()->create();
    $cashOnly = Customer::factory()->create(['credit_limit' => 0]);

    $this->postJson('/api/v1/sales', ['customer_id' => $free->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 9]]])->assertCreated();
    $this->postJson('/api/v1/sales', ['customer_id' => $cashOnly->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertStatus(422);
    $this->postJson('/api/v1/sales', ['customer_id' => $cashOnly->id, 'paid' => 1000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
});

it('counts what the customer already owes, less what they paid back', function () {
    $item = Item::factory()->create(['quantity' => 20, 'sell_price' => 1000]);
    $customer = Customer::factory()->create(['credit_limit' => 5000]);
    $sale = fn (int $qty, int $paid = 0) => $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => $paid, 'items' => [['item_id' => $item->id, 'quantity' => $qty]]]);

    $sale(5)->assertCreated();
    $sale(1)->assertStatus(422);
    $this->postJson('/api/v1/payments', ['customer_id' => $customer->id, 'amount' => 3000])->assertCreated();
    $sale(3)->assertCreated();
});

it('lets only the owner set a limit or go past it', function () {
    $customer = Customer::factory()->create(['credit_limit' => 1000]);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $body = ['customer_id' => $customer->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 3]]];

    $this->postJson('/api/v1/sales', $body)->assertStatus(422);
    $this->postJson('/api/v1/sales', $body + ['ignore_credit_limit' => true])->assertCreated();
    $this->patchJson("/api/v1/customers/{$customer->id}", ['name' => 'Ram', 'credit_limit' => 9000])
        ->assertOk()->assertJsonPath('data.credit_limit', 9000);

    Sanctum::actingAs(User::factory()->staff()->forBusiness($customer->business_id)->create());
    $this->postJson('/api/v1/sales', $body + ['ignore_credit_limit' => true])->assertStatus(422)->assertJsonValidationErrors('ignore_credit_limit');
    $this->patchJson("/api/v1/customers/{$customer->id}", ['name' => 'Ram', 'credit_limit' => 1])->assertStatus(422)->assertJsonValidationErrors('credit_limit');
});

it('shows the limit and what is owed in the ledger', function () {
    $customer = Customer::factory()->create(['credit_limit' => 5000]);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->assertCreated();

    $this->getJson("/api/v1/customers/{$customer->id}/ledger")
        ->assertOk()->assertJsonPath('owes', 2000)->assertJsonPath('credit_limit', 5000);

    expect(Sale::count())->toBe(1);
});
