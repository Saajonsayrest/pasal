<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\Sale;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

function saleBody(Item $item, int $qty = 1): array
{
    return ['paid' => $item->sell_price * $qty, 'items' => [['item_id' => $item->id, 'quantity' => $qty]]];
}

it('saves a sale once when the same request comes twice, and sends back the first answer', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $headers = ['Idempotency-Key' => 'sale-0001-abcd'];

    $first = $this->postJson('/api/v1/sales', saleBody($item), $headers)->assertCreated();
    $second = $this->postJson('/api/v1/sales', saleBody($item), $headers)->assertCreated()->assertHeader('Idempotent-Replayed', 'true');

    expect($second->json('data.id'))->toBe($first->json('data.id'))
        ->and(Sale::count())->toBe(1)
        ->and($item->refresh()->quantity)->toBe(9);
    $this->assertDatabaseCount('payments', 1);
});

it('treats a request without a key as a new one each time', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    $this->postJson('/api/v1/sales', saleBody($item))->assertCreated();
    $this->postJson('/api/v1/sales', saleBody($item))->assertCreated();

    expect(Sale::count())->toBe(2);
});

it('refuses a key that was used for a different request', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $headers = ['Idempotency-Key' => 'sale-0002-abcd'];

    $this->postJson('/api/v1/sales', saleBody($item, 1), $headers)->assertCreated();
    $this->postJson('/api/v1/sales', saleBody($item, 2), $headers)->assertStatus(422)->assertJsonValidationErrors('idempotency_key');

    expect(Sale::count())->toBe(1);
});

it('does not burn the key when the request was refused', function () {
    $item = Item::factory()->create(['quantity' => 1, 'sell_price' => 5000]);
    $headers = ['Idempotency-Key' => 'sale-0003-abcd'];

    $this->postJson('/api/v1/sales', saleBody($item, 5), $headers)->assertStatus(422);
    $this->assertDatabaseCount('idempotency_keys', 0);

    $this->postJson('/api/v1/sales', saleBody($item, 1), $headers)->assertCreated();
    $this->assertDatabaseCount('idempotency_keys', 1);
});

it('keeps each shop\'s keys apart', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $headers = ['Idempotency-Key' => 'shared-key-0001'];
    $this->postJson('/api/v1/sales', saleBody($item), $headers)->assertCreated();

    Sanctum::actingAs(User::factory()->create());
    $otherItem = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $response = $this->postJson('/api/v1/sales', saleBody($otherItem), $headers)->assertCreated();

    expect($response->headers->has('Idempotent-Replayed'))->toBeFalse()
        ->and($otherItem->refresh()->quantity)->toBe(9);
});

it('rejects a key that is too short or has odd characters', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    $this->postJson('/api/v1/sales', saleBody($item), ['Idempotency-Key' => 'short'])->assertStatus(422);
    $this->postJson('/api/v1/sales', saleBody($item), ['Idempotency-Key' => "bad key with spaces\n"])->assertStatus(422);
    expect(Sale::count())->toBe(0);
});

it('also protects payments and returns', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);
    $customer = Customer::factory()->create();
    $saleId = $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->json('data.id');
    $headers = ['Idempotency-Key' => 'pay-0001-abcdef'];

    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 4000], $headers)->assertCreated();
    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 4000], $headers)->assertCreated();

    expect(Sale::find($saleId)->paid)->toBe(4000);
    $this->assertDatabaseCount('payments', 1);
});

it('does not apply to a GET', function () {
    $this->getJson('/api/v1/sales', ['Idempotency-Key' => 'x'])->assertOk();
});
