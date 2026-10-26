<?php

use App\Models\Customer;
use App\Models\Item;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->owner = User::factory()->create();
    Sanctum::actingAs($this->owner);
});

it('saves a category icon and colour and rejects bad ones', function () {
    $this->postJson('/api/v1/categories', ['name' => 'Dairy', 'icon' => 'egg', 'color' => '#1f8a63'])
        ->assertCreated()->assertJsonPath('data.icon', 'egg')->assertJsonPath('data.color', '#1f8a63');

    $this->postJson('/api/v1/categories', ['name' => 'Bad', 'icon' => 'a b', 'color' => 'red'])
        ->assertUnprocessable()->assertJsonValidationErrors(['icon', 'color']);
});

it('stores an item photo under a random name and removes the old one', function () {
    Storage::fake('public');
    $item = Item::factory()->create();

    $first = $this->postJson("/api/v1/items/{$item->id}/photo", ['photo' => UploadedFile::fake()->image('../../evil.png')])
        ->assertOk()->json('data.photo_url');
    expect($first)->toContain("items/{$this->owner->business_id}/")->not->toContain('evil');

    $path = $item->fresh()->photo_path;
    Storage::disk('public')->assertExists($path);

    $this->postJson("/api/v1/items/{$item->id}/photo", ['photo' => UploadedFile::fake()->image('b.jpg')])->assertOk();
    Storage::disk('public')->assertMissing($path);

    $this->deleteJson("/api/v1/items/{$item->id}/photo")->assertOk()->assertJsonPath('data.photo_url', null);
});

it('refuses a photo that is not an image, too big, or from staff', function () {
    Storage::fake('public');
    $item = Item::factory()->create();

    $this->postJson("/api/v1/items/{$item->id}/photo", ['photo' => UploadedFile::fake()->create('a.pdf', 10, 'application/pdf')])->assertUnprocessable();
    $this->postJson("/api/v1/items/{$item->id}/photo", ['photo' => UploadedFile::fake()->image('big.png')->size(5000)])->assertUnprocessable();

    Sanctum::actingAs(User::factory()->staff()->forBusiness($this->owner->business_id)->create());
    $this->postJson("/api/v1/items/{$item->id}/photo", ['photo' => UploadedFile::fake()->image('a.png')])->assertForbidden();
});

it('reports sales per day and hour in Nepal time, net of returns', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000, 'vat_applies' => false]);
    // 2026-04-01 20:00 UTC is 01:45 on 2 April in Nepal.
    $this->postJson('/api/v1/sales', ['paid' => 3000, 'sold_at' => '2026-04-01 20:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 3]]])->assertCreated();
    $sale = $this->postJson('/api/v1/sales', ['paid' => 2000, 'sold_at' => '2026-04-02 05:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->json('data');
    $this->postJson("/api/v1/sales/{$sale['id']}/returns", ['items' => [['sale_item_id' => $sale['items'][0]['id'], 'quantity' => 1]]])->assertCreated();

    $res = $this->getJson('/api/v1/reports/daily?from=2026-04-02&to=2026-04-02')->assertOk();
    $res->assertJsonCount(1, 'days')->assertJsonPath('days.0.bills', 2)->assertJsonPath('hours.1.bills', 1)->assertJsonPath('hours.10.bills', 1);
    $res->assertJsonPath('days.0.sales', 5000);

    // The return counts on the day it happened (today), not on the day of the sale.
    $this->getJson('/api/v1/reports/daily?from='.now('Asia/Kathmandu')->toDateString().'&to='.now('Asia/Kathmandu')->toDateString())
        ->assertOk()->assertJsonPath('days.0.sales', -1000);
});

it('lists top and slow items', function () {
    $fast = Item::factory()->create(['name' => 'Fast', 'quantity' => 20, 'sell_price' => 100]);
    $slow = Item::factory()->create(['name' => 'Slow', 'quantity' => 9, 'sell_price' => 100]);
    $this->postJson('/api/v1/sales', ['paid' => 500, 'sold_at' => '2026-04-02 05:00:00', 'items' => [['item_id' => $fast->id, 'quantity' => 5]]])->assertCreated();

    $res = $this->getJson('/api/v1/reports/items?from=2026-04-01&to=2026-04-30')->assertOk();
    $res->assertJsonPath('top.0.name', 'Fast')->assertJsonPath('top.0.quantity', 5);
    expect(collect($res->json('slow'))->first()['name'])->toBe('Slow');
});

it('groups customer credit by age', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $c = Customer::factory()->create();
    $this->postJson('/api/v1/sales', ['customer_id' => $c->id, 'paid' => 0, 'sold_at' => now()->subDays(100)->toDateTimeString(), 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
    $this->postJson('/api/v1/sales', ['customer_id' => $c->id, 'paid' => 0, 'sold_at' => now()->subDays(5)->toDateTimeString(), 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->assertCreated();

    $res = $this->getJson('/api/v1/reports/credit-age')->assertOk();
    $res->assertJsonPath('total', 3000)->assertJsonPath('buckets.0.amount', 2000)->assertJsonPath('buckets.3.amount', 1000);
    $res->assertJsonPath('customers.0.owes', 3000)->assertJsonPath('customers.0.bucket', 'd90_plus');
});

it('reports sales per staff member', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $this->postJson('/api/v1/sales', ['paid' => 1000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();

    $this->getJson('/api/v1/reports/staff?from='.now()->toDateString().'&to='.now()->toDateString())
        ->assertOk()->assertJsonPath('data.0.name', $this->owner->name)->assertJsonPath('data.0.sales', 1000);
});

it('keeps the new reports for the owner', function () {
    Sanctum::actingAs(User::factory()->staff()->forBusiness($this->owner->business_id)->create());
    foreach (['reports/daily?from=2026-04-01&to=2026-04-02', 'reports/items?from=2026-04-01&to=2026-04-02', 'reports/credit-age', 'reports/staff?from=2026-04-01&to=2026-04-02', 'activity'] as $path) {
        $this->getJson("/api/v1/{$path}")->assertForbidden();
    }
});

it('shows notifications: low stock and old credit', function () {
    $item = Item::factory()->create(['name' => 'Sugar', 'quantity' => 2, 'low_stock_at' => 10, 'sell_price' => 1000]);
    $c = Customer::factory()->create(['name' => 'Hari']);
    $this->postJson('/api/v1/sales', ['customer_id' => $c->id, 'paid' => 0, 'sold_at' => now()->subDays(40)->toDateTimeString(), 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();

    $types = collect($this->getJson('/api/v1/notifications')->assertOk()->json('data'))->pluck('type');
    expect($types)->toContain('low_stock', 'credit_overdue');
});

it('numbers sales S-0001, S-0002 for each business and keeps typed numbers', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $sell = fn (array $extra = []) => $this->postJson('/api/v1/sales', ['paid' => 1000, 'items' => [['item_id' => $item->id, 'quantity' => 1]], ...$extra])->assertCreated()->json('data.bill_no');

    expect($sell())->toBe('S-0001');
    expect($sell(['bill_no' => 'MY-77']))->toBe('MY-77');
    expect($sell())->toBe('S-0002');
    expect($sell(['bill_no' => '']))->toBe('S-0003');

    // Another business starts from 1 again.
    Sanctum::actingAs(User::factory()->create());
    $other = Item::factory()->create(['quantity' => 5, 'sell_price' => 500]);
    $this->postJson('/api/v1/sales', ['paid' => 500, 'items' => [['item_id' => $other->id, 'quantity' => 1]]])->assertJsonPath('data.bill_no', 'S-0001');
});

it('lists customers with what they owe, filters and a business total', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $hari = Customer::factory()->create(['name' => 'Hari Thapa', 'phone' => '9800000001', 'credit_limit' => 1500]);
    $sita = Customer::factory()->create(['name' => 'Sita Gurung', 'phone' => '9800000002']);
    $this->postJson('/api/v1/sales', ['customer_id' => $hari->id, 'paid' => 500, 'items' => [['item_id' => $item->id, 'quantity' => 2]]])->assertCreated();
    $this->postJson('/api/v1/sales', ['customer_id' => $sita->id, 'paid' => 1000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();

    $res = $this->getJson('/api/v1/customers?sort=owed')->assertOk();
    $res->assertJsonPath('data.0.name', 'Hari Thapa')->assertJsonPath('data.0.owes', 1500)->assertJsonPath('data.1.owes', 0)
        ->assertJsonPath('summary.owed_total', 1500)->assertJsonPath('summary.owing_customers', 1);

    expect($this->getJson('/api/v1/customers?owes=1')->json('data'))->toHaveCount(1);
    expect($this->getJson('/api/v1/customers?paid_up=1')->json('data.0.name'))->toBe('Sita Gurung');
    expect($this->getJson('/api/v1/customers?search=9800000002')->json('data'))->toHaveCount(1);
    expect($this->getJson('/api/v1/customers?over_limit=1')->json('data'))->toHaveCount(0); // owes 1500, limit 1500
    $this->getJson("/api/v1/customers/{$hari->id}")->assertJsonPath('data.owes', 1500);
});

it('puts payments in the customer and supplier ledgers', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $customer = Customer::factory()->create();
    $this->postJson('/api/v1/sales', ['customer_id' => $customer->id, 'paid' => 400, 'bill_no' => 'S-9', 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
    $this->getJson("/api/v1/customers/{$customer->id}/ledger")->assertOk()
        ->assertJsonPath('sales.0.bill_no', 'S-9')->assertJsonPath('payments.0.amount', 400)->assertJsonPath('payments.0.direction', 'in');

    $supplier = \App\Models\Supplier::factory()->create();
    $this->postJson('/api/v1/purchases', ['supplier_id' => $supplier->id, 'paid' => 300, 'items' => [['item_id' => $item->id, 'quantity' => 1, 'unit_cost' => 1000]]])->assertCreated();
    $this->getJson("/api/v1/suppliers/{$supplier->id}/ledger")->assertOk()->assertJsonPath('payments.0.amount', 300)->assertJsonPath('payments.0.direction', 'out');
});

it('lists suppliers with what we owe them', function () {
    $item = Item::factory()->create();
    $supplier = \App\Models\Supplier::factory()->create(['name' => 'Everest Traders']);
    $this->postJson('/api/v1/purchases', ['supplier_id' => $supplier->id, 'paid' => 400, 'items' => [['item_id' => $item->id, 'quantity' => 1, 'unit_cost' => 1000]]])->assertCreated();

    $this->getJson('/api/v1/suppliers')->assertOk()
        ->assertJsonPath('data.0.we_owe', 600)->assertJsonPath('summary.owed_total', 600);
});

it('filters sales by day and search, and shows who sold', function () {
    $item = Item::factory()->create(['quantity' => 50, 'sell_price' => 1000]);
    $this->postJson('/api/v1/sales', ['paid' => 1000, 'bill_no' => 'S-0001', 'sold_at' => '2026-04-01 05:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
    $this->postJson('/api/v1/sales', ['paid' => 1000, 'bill_no' => 'S-0002', 'sold_at' => '2026-04-03 05:00:00', 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();

    $res = $this->getJson('/api/v1/sales?from=2026-04-03&to=2026-04-03')->assertOk();
    expect($res->json('data'))->toHaveCount(1);
    $res->assertJsonPath('data.0.bill_no', 'S-0002')->assertJsonPath('data.0.sold_by', $this->owner->name);
    expect($this->getJson('/api/v1/sales?search=S-0001')->json('data'))->toHaveCount(1);
});

it('shows the activity log with who did it, and stays inside the business', function () {
    $item = Item::factory()->create(['quantity' => 5, 'sell_price' => 1000]);
    $this->postJson('/api/v1/sales', ['paid' => 1000, 'items' => [['item_id' => $item->id, 'quantity' => 1]]])->assertCreated();
    $this->postJson('/api/v1/stock-adjustments', ['item_id' => $item->id, 'change' => -1, 'note' => 'damaged'])->assertOk();

    $res = $this->getJson('/api/v1/activity')->assertOk();
    $kinds = collect($res->json('data'))->pluck('kind');
    expect($kinds)->toContain('sale', 'payment_in', 'stock_adjust');
    expect(collect($res->json('data'))->firstWhere('kind', 'sale')['by'])->toBe($this->owner->name);

    Sanctum::actingAs(User::factory()->create());
    $this->getJson('/api/v1/activity')->assertOk()->assertJsonPath('meta.total', 0);
});
