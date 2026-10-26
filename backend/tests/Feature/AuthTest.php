<?php

use App\Models\User;

it('logs in with the right password and returns a token', function () {
    $user = User::factory()->create(['password' => 'secret-pass-1']);

    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'secret-pass-1'])
        ->assertOk()
        ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);
});

it('rejects a wrong password with the standard error shape', function () {
    $user = User::factory()->create();

    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'wrong'])
        ->assertStatus(422)
        ->assertJsonStructure(['message', 'errors' => ['email']]);
});

it('blocks protected routes without a token', function () {
    $this->getJson('/api/v1/me')->assertUnauthorized();
});

it('blocks every data route without a token', function (string $method, string $url) {
    $this->json($method, $url)->assertUnauthorized();
})->with([
    ['GET', '/api/v1/items'],
    ['POST', '/api/v1/items'],
    ['GET', '/api/v1/suppliers'],
    ['GET', '/api/v1/customers'],
    ['GET', '/api/v1/sales'],
    ['POST', '/api/v1/sales'],
    ['GET', '/api/v1/purchases'],
    ['POST', '/api/v1/payments'],
    ['GET', '/api/v1/expenses'],
    ['GET', '/api/v1/customers/1/ledger'],
    ['GET', '/api/v1/reports/summary'],
]);

it('shows the current user and logs out', function () {
    $user = User::factory()->create(['password' => 'secret-pass-1']);
    $token = $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'secret-pass-1'])
        ->json('token');

    $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('email', $user->email);
    $this->withToken($token)->postJson('/api/v1/logout')->assertOk();
    expect($user->tokens()->count())->toBe(0);
});
