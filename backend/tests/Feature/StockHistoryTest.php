<?php

use App\Models\Item;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

it('lists every change of one item, newest first, with who and why', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $this->postJson('/api/v1/sales', ['paid' => 2000, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->assertCreated();
    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => -1, 'note' => 'Broken'])->assertOk();

    $this->getJson("/api/v1/items/{$item->id}/stock-movements")
        ->assertOk()
        ->assertJsonPath('item.quantity', 7)
        ->assertJsonPath('data.0.reason', 'adjust')
        ->assertJsonPath('data.0.change', -1)
        ->assertJsonPath('data.0.note', 'Broken')
        ->assertJsonPath('data.0.by', auth()->user()->name)
        ->assertJsonPath('data.1.reason', 'sale')
        ->assertJsonPath('data.1.ref_type', 'sale')
        ->assertJsonStructure(['data' => [['id', 'change', 'reason', 'ref_type', 'ref_id', 'note', 'by', 'at']], 'links', 'meta' => ['current_page', 'per_page', 'total']]);
});

it('shows only the owner the stock history', function () {
    $item = Item::factory()->create();
    Sanctum::actingAs(User::factory()->staff()->forBusiness($item->business_id)->create());

    $this->getJson("/api/v1/items/{$item->id}/stock-movements")->assertForbidden();
});

it('does not show the history of another shop\'s item', function () {
    $item = Item::factory()->create();
    Sanctum::actingAs(User::factory()->create());

    $this->getJson("/api/v1/items/{$item->id}/stock-movements")->assertNotFound();
});

it('fixes the system to match a stock count and writes history only where it differs', function () {
    $short = Item::factory()->create(['quantity' => 10]);
    $over = Item::factory()->create(['quantity' => 3]);
    $same = Item::factory()->create(['quantity' => 5]);

    $this->postJson('/api/v1/stock-counts', ['note' => 'Month end', 'items' => [
        ['item_id' => $short->id, 'counted' => 7],
        ['item_id' => $over->id, 'counted' => 4],
        ['item_id' => $same->id, 'counted' => 5],
    ]])
        ->assertCreated()
        ->assertJsonPath('items_changed', 2)
        ->assertJsonPath('data.0.system', 10)
        ->assertJsonPath('data.0.counted', 7)
        ->assertJsonPath('data.0.difference', -3);

    expect($short->refresh()->quantity)->toBe(7)
        ->and($over->refresh()->quantity)->toBe(4)
        ->and($same->refresh()->quantity)->toBe(5);
    $this->assertDatabaseHas('stock_movements', ['item_id' => $short->id, 'change' => -3, 'reason' => 'count', 'note' => 'Month end']);
    $this->assertDatabaseMissing('stock_movements', ['item_id' => $same->id]);
});

it('can count an item down to zero', function () {
    $item = Item::factory()->create(['quantity' => 4]);

    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => 0]]])->assertCreated();

    expect($item->refresh()->quantity)->toBe(0);
});

it('checks a stock count before it saves anything', function () {
    $item = Item::factory()->create(['quantity' => 4]);
    $stranger = Item::factory()->create(); // same shop, used below for a duplicate

    $this->postJson('/api/v1/stock-counts', ['items' => []])->assertStatus(422);
    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => -1]]])->assertStatus(422);
    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => 1], ['item_id' => $item->id, 'counted' => 2]]])->assertStatus(422);
    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => 1], ['item_id' => 999999, 'counted' => 2]]])->assertStatus(422);

    expect($item->refresh()->quantity)->toBe(4)->and($stranger->quantity)->not->toBeNull();
});

it('does not let staff count stock, and does not touch another shop\'s items', function () {
    $item = Item::factory()->create(['quantity' => 4]);

    Sanctum::actingAs(User::factory()->staff()->forBusiness($item->business_id)->create());
    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => 1]]])->assertForbidden();

    Sanctum::actingAs(User::factory()->create());
    $this->postJson('/api/v1/stock-counts', ['items' => [['item_id' => $item->id, 'counted' => 1]]])->assertStatus(422);
    expect($item->refresh()->quantity)->toBe(4);
});
