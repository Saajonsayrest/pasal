<?php

use App\Models\Item;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Laravel\Sanctum\Sanctum;

it('hides internal class names on a missing record', function () {
    Sanctum::actingAs(User::factory()->create());

    $response = $this->getJson('/api/v1/items/999999')->assertNotFound()->assertExactJson(['message' => 'Not found.']);

    expect($response->getContent())->not->toContain('App\\Models');
});

it('gives a clean JSON error for an unknown url and a wrong method', function () {
    $this->getJson('/api/v1/nothing-here')->assertNotFound()->assertExactJson(['message' => 'Not found.']);
    $this->putJson('/api/v1/login')->assertStatus(405)->assertExactJson(['message' => 'Method not allowed.']);
});

it('sends safety headers and forbids caching', function () {
    $this->getJson('/api/v1/me')
        ->assertHeader('X-Content-Type-Options', 'nosniff')
        ->assertHeader('X-Frame-Options', 'DENY')
        ->assertHeader('Referrer-Policy', 'no-referrer')
        ->assertHeader('Cache-Control', 'no-store, private');
});

it('rejects huge numbers with 422 instead of crashing', function () {
    Sanctum::actingAs(User::factory()->create());
    $item = Item::factory()->create();

    $this->postJson('/api/v1/sales', ['paid' => 0, 'items' => [['item_id' => $item->id, 'quantity' => 99999999999]]])
        ->assertStatus(422);
    $this->postJson('/api/v1/items', ['name' => 'X', 'sku' => 'BIG', 'cost_price' => 99999999999999, 'sell_price' => 1])
        ->assertStatus(422);
    $this->postJson('/api/v1/expenses', ['title' => 'X', 'amount' => 9223372036854775807])
        ->assertStatus(422);
});

it('logs a failed login without writing the password', function () {
    Log::spy();
    $user = User::factory()->create();

    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'not-the-password'])->assertStatus(422);

    Log::shouldHaveReceived('warning')->once()->withArgs(
        fn ($message, $context) => $message === 'Failed login' && ! in_array('not-the-password', $context, true)
    );
});

it('stops the sixth login try in a minute', function () {
    $user = User::factory()->create();

    foreach (range(1, 5) as $_) {
        $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'wrong'])->assertStatus(422);
    }

    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'wrong'])->assertStatus(429);
});

it('rejects a token that was revoked', function () {
    $user = User::factory()->create(['password' => 'secret-pass-1']);
    $token = $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'secret-pass-1'])->json('token');

    $user->tokens()->delete();
    $this->app['auth']->forgetGuards();

    $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
});
