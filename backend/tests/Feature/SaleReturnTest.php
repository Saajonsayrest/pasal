<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\SaleReturn;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(fn () => Sanctum::actingAs(User::factory()->create()));

/** A sale of three 11300 items (VAT 1300 each). */
function sellThree(object $test, array $extra = []): array
{
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 11300, 'cost_price' => 8000]);
    $response = $test->postJson('/api/v1/sales', $extra + ['paid' => 33900, 'items' => [['item_id' => $item->id, 'quantity' => 3]]])->assertCreated();

    return [$item, $response->json('data.id'), $response->json('data.total')];
}

it('takes goods back, restocks them and refunds the money', function () {
    [$item, $saleId] = sellThree($this);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]], 'note' => 'Wrong size'])
        ->assertCreated()
        ->assertJsonPath('data.kind', 'return')
        ->assertJsonPath('data.total', 11300)
        ->assertJsonPath('data.vat_amount', 1300)
        ->assertJsonPath('data.refunded', 11300)
        ->assertJsonPath('sale_balance', 0)
        ->assertJsonPath('sale_cancelled', false);

    expect($item->refresh()->quantity)->toBe(8); // 10 - 3 sold + 1 back
    $this->assertDatabaseHas('payments', ['sale_id' => $saleId, 'direction' => 'refund', 'amount' => 11300]);
    $this->assertDatabaseHas('stock_movements', ['item_id' => $item->id, 'change' => 1, 'reason' => 'sale_return']);

    $this->getJson("/api/v1/sales/{$saleId}")
        ->assertJsonPath('data.paid', 22600)
        ->assertJsonPath('data.returned_total', 11300)
        ->assertJsonPath('data.items.0.returned_quantity', 1)
        ->assertJsonPath('data.returns.0.items.0.quantity', 1);
});

it('lowers udhar first and refunds nothing while the customer still owes more', function () {
    $customer = Customer::factory()->create();
    [, $saleId] = sellThree($this, ['customer_id' => $customer->id, 'paid' => 10000]);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]]])
        ->assertCreated()->assertJsonPath('data.refunded', 0)->assertJsonPath('sale_balance', 12600);

    $this->getJson("/api/v1/customers/{$customer->id}/ledger")->assertJsonPath('owes', 12600)->assertJsonPath('total_sales', 22600);
    $this->assertDatabaseMissing('payments', ['direction' => 'refund']);
});

it('refunds only the part that was paid beyond the new total', function () {
    $customer = Customer::factory()->create();
    [, $saleId] = sellThree($this, ['customer_id' => $customer->id, 'paid' => 30000]);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    // New total 22600, paid 30000, so 7400 goes back.
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]]])
        ->assertCreated()->assertJsonPath('data.refunded', 7400)->assertJsonPath('sale_balance', 0);

    $this->getJson("/api/v1/sales/{$saleId}")->assertJsonPath('data.paid', 22600);
});

it('cancels a whole sale: stock back, money back, and the sale is closed', function () {
    [$item, $saleId] = sellThree($this);

    $this->postJson("/api/v1/sales/{$saleId}/cancel", ['note' => 'Customer left'])
        ->assertCreated()
        ->assertJsonPath('data.kind', 'cancel')
        ->assertJsonPath('data.total', 33900)
        ->assertJsonPath('data.vat_amount', 3900)
        ->assertJsonPath('data.refunded', 33900)
        ->assertJsonPath('sale_cancelled', true);

    expect($item->refresh()->quantity)->toBe(10);
    $this->getJson("/api/v1/sales/{$saleId}")->assertJsonPath('data.paid', 0)->assertJsonPath('data.balance', 0);

    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertStatus(422)->assertJsonValidationErrors('sale');
    $this->postJson('/api/v1/payments', ['sale_id' => $saleId, 'amount' => 1])->assertStatus(422)->assertJsonValidationErrors('amount');
});

it('adds up the VAT of several returns to exactly the VAT of the sale', function () {
    [, $saleId] = sellThree($this);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    foreach ([1, 1, 1] as $ignored) {
        $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]]])->assertCreated();
    }

    expect((int) SaleReturn::sum('vat_amount'))->toBe(3900)
        ->and((int) SaleReturn::sum('total'))->toBe(33900);
    $this->getJson("/api/v1/sales/{$saleId}")->assertJsonPath('data.cancelled_at', fn ($v) => $v !== null);
});

it('returns a discounted sale for what the customer really paid', function () {
    $item = Item::factory()->create(['quantity' => 10, 'sell_price' => 1000]);
    $saleId = $this->postJson('/api/v1/sales', ['paid' => 2700, 'discount' => 300, 'items' => [['item_id' => $item->id, 'quantity' => 3]]])
        ->assertCreated()->json('data.id');
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    // 3 x 1000 less 300 = 2700. One unit back is 900.
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]]])
        ->assertCreated()->assertJsonPath('data.total', 900)->assertJsonPath('data.refunded', 900);
    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertCreated()->assertJsonPath('data.total', 1800);
});

it('does not restock goods marked as damaged', function () {
    [$item, $saleId] = sellThree($this);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');

    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]], 'restock' => false])->assertCreated();

    expect($item->refresh()->quantity)->toBe(7);
});

it('refuses to return more than was sold, or a line from another sale', function () {
    [, $saleId] = sellThree($this);
    [, $otherSaleId] = sellThree($this);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');
    $otherLine = $this->getJson("/api/v1/sales/{$otherSaleId}")->json('data.items.0.id');

    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 4]]])->assertStatus(422)->assertJsonValidationErrors('items');
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 2], ['sale_item_id' => $line, 'quantity' => 2]]])->assertStatus(422);
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $otherLine, 'quantity' => 1]]])->assertStatus(422);
});

it('lets only the owner return or cancel', function () {
    [, $saleId] = sellThree($this);
    Sanctum::actingAs(User::factory()->staff()->forBusiness(auth()->user()->business_id)->create());

    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertForbidden();
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => 1, 'quantity' => 1]]])->assertForbidden();
});

it('does not let another shop return or cancel my sale', function () {
    [$item, $saleId] = sellThree($this);
    Sanctum::actingAs(User::factory()->create());

    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertNotFound();
    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => 1, 'quantity' => 1]]])->assertNotFound();

    expect($item->refresh()->quantity)->toBe(7);
});

it('takes a return out of sales, VAT and profit on the day it happened', function () {
    [, $saleId] = sellThree($this);
    $today = now()->toDateString();

    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertCreated();

    $this->getJson("/api/v1/reports/summary?from={$today}&to={$today}")
        ->assertOk()
        ->assertJsonPath('sales_total', 0)
        ->assertJsonPath('vat_collected', 0)
        ->assertJsonPath('cost_of_goods', 0)
        ->assertJsonPath('profit', 0);

    $this->getJson("/api/v1/vat/preview?from={$today}&to={$today}")
        ->assertOk()->assertJsonPath('output_vat', 0)->assertJsonPath('sales_taxable', 0)->assertJsonPath('payable', 0);
});

it('keeps the cost of goods that were not put back on the shelf', function () {
    [, $saleId] = sellThree($this);
    $line = $this->getJson("/api/v1/sales/{$saleId}")->json('data.items.0.id');
    $today = now()->toDateString();

    $this->postJson("/api/v1/sales/{$saleId}/returns", ['items' => [['sale_item_id' => $line, 'quantity' => 1]], 'restock' => false])->assertCreated();

    // Sold 3 (cost 24000), one came back broken, so its cost 8000 stays a loss.
    $this->getJson("/api/v1/reports/summary?from={$today}&to={$today}")
        ->assertJsonPath('sales_total', 22600)->assertJsonPath('cost_of_goods', 24000);
});

it('works with a deleted item', function () {
    [$item, $saleId] = sellThree($this);
    $item->delete();

    $this->postJson("/api/v1/sales/{$saleId}/cancel")->assertCreated();

    expect(Item::withTrashed()->find($item->id)->quantity)->toBe(10);
});
