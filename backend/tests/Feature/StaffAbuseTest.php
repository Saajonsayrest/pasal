<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\Sale;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

// Attack tests: things a staff member could try by calling the API directly, without the app.

function ownerAndStaff(): array
{
    $owner = User::factory()->create();
    $staff = User::factory()->staff()->forBusiness($owner->business_id)->create();

    return [$owner, $staff];
}

it('stops staff from selling below the list price, which would get around the discount cap', function () {
    [$owner, $staff] = ownerAndStaff();
    Sanctum::actingAs($owner);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    Sanctum::actingAs($staff);
    $this->postJson('/api/v1/sales', ['paid' => 1, 'items' => [['item_id' => $item->id, 'quantity' => 1, 'unit_price' => 1]]])
        ->assertStatus(422)
        ->assertJsonValidationErrors('items.0.unit_price');

    expect(Sale::count())->toBe(0)->and($item->fresh()->quantity)->toBe(10);

    // The owner may still agree a different price.
    Sanctum::actingAs($owner);
    $this->postJson('/api/v1/sales', ['paid' => 4500, 'items' => [['item_id' => $item->id, 'quantity' => 1, 'unit_price' => 4500]]])
        ->assertCreated();
});

it('stops staff from backdating a sale or choosing its bill number', function () {
    [$owner, $staff] = ownerAndStaff();
    Sanctum::actingAs($owner);
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 5000]);

    Sanctum::actingAs($staff);
    $line = [['item_id' => $item->id, 'quantity' => 1]];

    $this->postJson('/api/v1/sales', ['paid' => 5000, 'sold_at' => '2020-01-01 10:00:00', 'items' => $line])
        ->assertStatus(422)->assertJsonValidationErrors('sold_at');
    $this->postJson('/api/v1/sales', ['paid' => 5000, 'bill_no' => 'S-999999', 'items' => $line])
        ->assertStatus(422)->assertJsonValidationErrors('bill_no');

    expect(Sale::count())->toBe(0);

    // A normal counter sale still works and gets its number from the server.
    $this->postJson('/api/v1/sales', ['paid' => 5000, 'items' => $line])
        ->assertCreated()->assertJsonPath('data.bill_no', 'S-0001');
});

it('lets only the owner delete a customer', function () {
    [$owner, $staff] = ownerAndStaff();
    Sanctum::actingAs($owner);
    $customer = Customer::factory()->create();

    Sanctum::actingAs($staff);
    $this->deleteJson("/api/v1/customers/{$customer->id}")->assertForbidden();
    expect(Customer::count())->toBe(1);

    Sanctum::actingAs($owner);
    $this->deleteJson("/api/v1/customers/{$customer->id}")->assertOk();
    expect(Customer::count())->toBe(0);
});
