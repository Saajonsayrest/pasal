<?php

use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    Sanctum::actingAs(User::factory()->create());
    config(['pasal.vat_rate' => 13]);
});

function sellVat(object $test, Item $item, int $qty): void
{
    $test->postJson('/api/v1/sales', ['paid' => $qty * $item->sell_price, 'items' => [['item_id' => $item->id, 'quantity' => $qty]]])->assertCreated();
}

function buyVat(object $test, Item $item, int $qty, int $cost, int $vat): void
{
    $test->postJson('/api/v1/purchases', [
        'supplier_id' => Supplier::factory()->create()->id, 'bill_no' => 'B-1', 'vat_amount' => $vat,
        'items' => [['item_id' => $item->id, 'quantity' => $qty, 'unit_cost' => $cost]],
    ])->assertCreated();
}

it('splits a VAT-inclusive sale into price and 13% VAT', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300]);

    $this->postJson('/api/v1/sales', ['paid' => 11300, 'bill_no' => 'S-1', 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertCreated()
        ->assertJsonPath('data.total', 11300)
        ->assertJsonPath('data.vat_amount', 1300)
        ->assertJsonPath('data.taxable_amount', 10000)
        ->assertJsonPath('data.exempt_amount', 0);
});

it('puts a no-VAT item in exempt, not in taxable', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000, 'vat_applies' => false]);

    $this->postJson('/api/v1/sales', ['paid' => 5000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])
        ->assertCreated()
        ->assertJsonPath('data.vat_amount', 0)
        ->assertJsonPath('data.exempt_amount', 5000);
});

it('adds the supplier bill VAT on top of the purchase cost', function () {
    $item = Item::factory()->create(['quantity' => 0]);

    $this->postJson('/api/v1/purchases', [
        'supplier_id' => Supplier::factory()->create()->id, 'vat_amount' => 1300,
        'items' => [['item_id' => $item->id, 'quantity' => 10, 'unit_cost' => 1000]],
    ])->assertCreated()->assertJsonPath('data.total', 11300);
});

it('works out VAT payable as sales VAT minus purchase VAT', function () {
    $item = Item::factory()->create(['quantity' => 100, 'sell_price' => 11300]);
    sellVat($this, $item, 10); // sales VAT 13000
    buyVat($this, $item, 5, 10000, 6500); // purchase VAT 6500
    $today = now()->toDateString();

    $this->getJson("/api/v1/vat/preview?from={$today}&to={$today}")
        ->assertOk()
        ->assertJsonPath('output_vat', 13000)
        ->assertJsonPath('input_vat', 6500)
        ->assertJsonPath('payable', 6500)
        ->assertJsonPath('carry_out', 0);
});

it('carries extra purchase VAT forward instead of paying', function () {
    $item = Item::factory()->create(['quantity' => 100, 'sell_price' => 11300]);
    sellVat($this, $item, 1); // sales VAT 1300
    buyVat($this, $item, 5, 10000, 6500); // purchase VAT 6500
    $today = now()->toDateString();

    $this->getJson("/api/v1/vat/preview?from={$today}&to={$today}")
        ->assertOk()
        ->assertJsonPath('payable', 0)
        ->assertJsonPath('carry_out', 5200);
});

it('uses an opening carry-forward typed by you for the first period', function () {
    $item = Item::factory()->create(['quantity' => 100, 'sell_price' => 11300]);
    sellVat($this, $item, 10); // 13000
    $today = now()->toDateString();

    $this->getJson("/api/v1/vat/preview?from={$today}&to={$today}&opening_carry=3000")
        ->assertOk()
        ->assertJsonPath('carry_in', 3000)
        ->assertJsonPath('payable', 10000);
});

it('saves a filing, then the next period starts with its carry-out', function () {
    $item = Item::factory()->create(['quantity' => 100, 'sell_price' => 11300]);
    sellVat($this, $item, 1);
    buyVat($this, $item, 5, 10000, 6500);
    $today = now()->toDateString();

    $this->postJson('/api/v1/vat/filings', ['period' => '2083-07', 'from' => $today, 'to' => $today])
        ->assertCreated()
        ->assertJsonPath('data.carry_out', 5200)
        ->assertJsonPath('data.source', 'computed');

    $next = now()->addDay()->toDateString();
    $this->getJson("/api/v1/vat/preview?from={$next}&to={$next}")->assertOk()->assertJsonPath('carry_in', 5200);
});

it('refuses a period that overlaps a saved one', function () {
    $today = now()->toDateString();
    $this->postJson('/api/v1/vat/filings', ['period' => '2083-07', 'from' => $today, 'to' => $today])->assertCreated();

    $this->postJson('/api/v1/vat/filings', ['period' => '2083-08', 'from' => $today, 'to' => $today])
        ->assertStatus(422)
        ->assertJsonValidationErrors('from');
});

it('stores an old return typed in by hand', function () {
    $this->postJson('/api/v1/vat/filings', [
        'manual' => true, 'period' => '2083-05', 'from' => '2026-08-17', 'to' => '2026-09-16',
        'sales_taxable' => 1000000, 'sales_exempt' => 0, 'output_vat' => 130000, 'purchases_taxable' => 600000,
        'input_vat' => 78000, 'carry_in' => 0, 'payable' => 52000, 'carry_out' => 0,
        'filed_on' => '2026-09-30', 'paid_amount' => 52000, 'receipt_no' => 'R-123',
    ])->assertCreated()->assertJsonPath('data.source', 'manual')->assertJsonPath('data.payable', 52000);
});

it('does not let a computed filing take typed-in numbers', function () {
    $today = now()->toDateString();

    $this->postJson('/api/v1/vat/filings', ['period' => 'x', 'from' => $today, 'to' => $today, 'payable' => 1])
        ->assertStatus(422)
        ->assertJsonValidationErrors('payable');
});

it('lets you record payment details later but never change the numbers', function () {
    $today = now()->toDateString();
    $id = $this->postJson('/api/v1/vat/filings', ['period' => '2083-07', 'from' => $today, 'to' => $today])->json('data.id');

    $this->patchJson("/api/v1/vat/filings/{$id}", ['filed_on' => $today, 'receipt_no' => 'R-9', 'output_vat' => 999999])
        ->assertOk()
        ->assertJsonPath('data.receipt_no', 'R-9')
        ->assertJsonPath('data.output_vat', 0);
});
