<?php

use App\Models\Item;
use App\Models\Supplier;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

it('creates an item and ignores a sent quantity', function () {
    $this->postJson('/api/v1/items', [
        'name' => 'Rice 5kg', 'sku' => 'RICE-5', 'cost_price' => 90000, 'sell_price' => 100000, 'quantity' => 999,
    ])->assertCreated()->assertJsonPath('data.quantity', 0);
});

it('rejects a duplicate sku', function () {
    Item::factory()->create(['sku' => 'DUP-1']);

    $this->postJson('/api/v1/items', ['name' => 'X', 'sku' => 'DUP-1', 'cost_price' => 1, 'sell_price' => 2])
        ->assertStatus(422)
        ->assertJsonValidationErrors('sku');
});

it('lists only low stock items when asked', function () {
    Item::factory()->create(['quantity' => 1, 'low_stock_at' => 3]);
    Item::factory()->create(['quantity' => 50, 'low_stock_at' => 3]);

    $this->getJson('/api/v1/items?low_stock=1')->assertOk()->assertJsonCount(1, 'data');
});

it('caps page size at 50', function () {
    Item::factory()->count(60)->create();

    $this->getJson('/api/v1/items?per_page=500')->assertOk()->assertJsonCount(50, 'data');
});

it('adjusts stock and writes a history row', function () {
    $item = Item::factory()->create(['quantity' => 10]);

    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => -4, 'note' => 'damaged'])
        ->assertOk()
        ->assertJsonPath('data.quantity', 6);

    $this->assertDatabaseHas('stock_movements', ['item_id' => $item->id, 'change' => -4, 'reason' => 'adjust']);
});

it('refuses to take stock below zero', function () {
    $item = Item::factory()->create(['quantity' => 2]);

    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => -5, 'note' => 'oops'])
        ->assertStatus(422);

    expect($item->refresh()->quantity)->toBe(2);
});

it('keeps deleted suppliers hidden but in the database', function () {
    $supplier = Supplier::factory()->create();

    $this->deleteJson("/api/v1/suppliers/{$supplier->id}")->assertOk();

    $this->getJson("/api/v1/suppliers/{$supplier->id}")->assertNotFound();
    $this->assertSoftDeleted($supplier);
});
