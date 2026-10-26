<?php

use App\Models\Item;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->owner = User::factory()->create();
    Sanctum::actingAs($this->owner);
});

function newItem(object $test, string $name, array $extra = []): \Illuminate\Testing\TestResponse
{
    return $test->postJson('/api/v1/items', ['name' => $name, 'cost_price' => 100, 'sell_price' => 150, ...$extra]);
}

it('suggests your own items, names that start with the text first', function () {
    Item::factory()->create(['name' => 'Basmati Rice 5kg']);
    Item::factory()->create(['name' => 'Rice Flour']);
    Item::factory()->create(['name' => 'Sugar']);

    $names = $this->getJson('/api/v1/items/suggest?q=rice')->assertOk()->json('data.*.name');

    expect($names)->toBe(['Rice Flour', 'Basmati Rice 5kg']);
});

it('suggests nothing for empty text and never shows other businesses or deleted items', function () {
    $other = User::factory()->create();
    Sanctum::actingAs($other);
    Item::factory()->create(['name' => 'Rice Secret']);

    Sanctum::actingAs($this->owner);
    Item::factory()->create(['name' => 'Rice Old', 'quantity' => 0])->delete();

    $this->getJson('/api/v1/items/suggest?q=')->assertOk()->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/items/suggest?q=rice')->assertOk()->assertJsonCount(0, 'data');
});

it('treats % and _ in the search text as plain letters', function () {
    Item::factory()->create(['name' => 'Plain item']);

    $this->getJson('/api/v1/items/suggest?q=%25')->assertOk()->assertJsonCount(0, 'data');
});

it('lets staff use the suggestions but hides the buying price', function () {
    Item::factory()->create(['name' => 'Rice', 'cost_price' => 900]);
    $staff = User::factory()->staff()->forBusiness($this->owner->business_id)->create();
    Sanctum::actingAs($staff);

    $this->getJson('/api/v1/items/suggest?q=ri')->assertOk()->assertJsonPath('data.0.name', 'Rice')->assertJsonPath('data.0.cost_price', null);
});

it('refuses a name that already exists, ignoring capitals and extra spaces, and points to the item', function () {
    $id = newItem($this, 'Rice 5kg')->assertCreated()->json('data.id');

    newItem($this, '  rice    5KG ')
        ->assertStatus(422)
        ->assertJsonValidationErrors('name')
        ->assertJsonPath('existing_item.id', $id)
        ->assertJsonPath('existing_item.deleted', false);
});

it('cleans extra spaces from a saved name', function () {
    newItem($this, '  Brown   Sugar ')->assertCreated()->assertJsonPath('data.name', 'Brown Sugar');
});

it('lets two businesses use the same item name', function () {
    newItem($this, 'Rice 5kg')->assertCreated();

    Sanctum::actingAs(User::factory()->create());
    newItem($this, 'Rice 5kg')->assertCreated();
});

it('lets an item keep its own name when it is edited', function () {
    $id = newItem($this, 'Rice 5kg')->json('data.id');

    $this->putJson("/api/v1/items/{$id}", ['name' => 'Rice 5kg', 'cost_price' => 200, 'sell_price' => 300])
        ->assertOk()->assertJsonPath('data.sell_price', 300);

    newItem($this, 'Sugar')->assertCreated();
    $this->putJson("/api/v1/items/{$id}", ['name' => 'sugar', 'cost_price' => 1, 'sell_price' => 2])->assertStatus(422);
});

it('does not need a SKU, and several items may have none', function () {
    newItem($this, 'Loose Rice')->assertCreated()->assertJsonPath('data.sku', null);
    newItem($this, 'Loose Sugar', ['sku' => ''])->assertCreated()->assertJsonPath('data.sku', null);
});

it('stops a deleted name from being made again and offers to restore it', function () {
    $id = newItem($this, 'Old Rice')->json('data.id');
    $this->deleteJson("/api/v1/items/{$id}")->assertOk();

    newItem($this, 'old rice')
        ->assertStatus(422)
        ->assertJsonPath('existing_item.id', $id)
        ->assertJsonPath('existing_item.deleted', true);

    $this->getJson('/api/v1/items?trashed=only')->assertOk()->assertJsonCount(1, 'data');

    $this->postJson("/api/v1/items/{$id}/restore")->assertOk()->assertJsonPath('data.name', 'Old Rice');
    $this->getJson("/api/v1/items/{$id}")->assertOk();
    $this->getJson('/api/v1/items?trashed=only')->assertJsonCount(0, 'data');
});

it('refuses to delete an item that still has stock', function () {
    $item = Item::factory()->create(['quantity' => 4]);

    $this->deleteJson("/api/v1/items/{$item->id}")->assertStatus(422)->assertJsonValidationErrors('quantity');
    $this->getJson("/api/v1/items/{$item->id}")->assertOk();

    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => -4, 'note' => 'sold off'])->assertOk();
    $this->deleteJson("/api/v1/items/{$item->id}")->assertOk();
});

it('keeps old sales readable after an item is deleted', function () {
    $item = Item::factory()->create(['quantity' => 1, 'sell_price' => 500, 'name' => 'Gone Soon']);
    $saleId = $this->postJson('/api/v1/sales', ['paid' => 500, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->json('data.id');
    $this->deleteJson("/api/v1/items/{$item->id}")->assertOk();

    $this->getJson("/api/v1/sales/{$saleId}")->assertOk()->assertJsonPath('data.items.0.item_name', 'Gone Soon');
});

it('keeps deleted items and restore away from staff and other businesses', function () {
    $id = newItem($this, 'Hidden')->json('data.id');
    $this->deleteJson("/api/v1/items/{$id}")->assertOk();

    $staff = User::factory()->staff()->forBusiness($this->owner->business_id)->create();
    Sanctum::actingAs($staff);
    $this->getJson('/api/v1/items?trashed=only')->assertForbidden();
    $this->postJson("/api/v1/items/{$id}/restore")->assertForbidden();

    Sanctum::actingAs(User::factory()->create());
    $this->postJson("/api/v1/items/{$id}/restore")->assertNotFound();
});

it('blocks the same name at the database even if the app check is skipped', function () {
    Item::factory()->create(['name' => 'Twin']);

    expect(fn () => Item::factory()->create(['name' => 'TWIN']))->toThrow(\Illuminate\Database\UniqueConstraintViolationException::class);
});
