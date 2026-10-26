<?php

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;

/** Asks for a reset and returns the token that was mailed. */
function mailedToken(object $test, User $user): string
{
    Notification::fake();
    $test->postJson('/api/v1/forgot-password', ['email' => $user->email])->assertOk();

    $token = null;
    Notification::assertSentTo($user, ResetPassword::class, function ($notification) use (&$token) {
        $token = $notification->token;

        return true;
    });

    return $token;
}

it('mails a reset link to the person, pointing at the app', function () {
    $user = User::factory()->create();
    Notification::fake();

    $this->postJson('/api/v1/forgot-password', ['email' => $user->email])
        ->assertOk()->assertJsonPath('message', 'If this email has an account, a reset link was sent.');

    Notification::assertSentTo($user, ResetPassword::class, function ($notification) use ($user) {
        $url = (new ReflectionMethod($notification, 'resetUrl'))->invoke($notification, $user);

        return str_starts_with($url, 'pasal://reset-password?token='.$notification->token)
            && str_contains($url, 'email='.urlencode($user->email));
    });
});

it('gives the same answer for an email that has no account, and sends nothing', function () {
    Notification::fake();

    $this->postJson('/api/v1/forgot-password', ['email' => 'nobody@example.com'])
        ->assertOk()->assertJsonPath('message', 'If this email has an account, a reset link was sent.');

    Notification::assertNothingSent();
});

it('sets a new password with the mailed token and signs out every phone', function () {
    $user = User::factory()->create();
    $user->createToken('phone');
    $user->createToken('tablet');
    $token = mailedToken($this, $user);

    $this->postJson('/api/v1/reset-password', ['email' => $user->email, 'token' => $token, 'password' => 'a-brand-new-pass-1'])
        ->assertOk();

    expect(Hash::check('a-brand-new-pass-1', $user->refresh()->password))->toBeTrue()
        ->and($user->tokens()->count())->toBe(0);
    $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'a-brand-new-pass-1'])->assertOk()->assertJsonStructure(['token']);
});

it('works only once', function () {
    $user = User::factory()->create();
    $token = mailedToken($this, $user);
    $body = ['email' => $user->email, 'token' => $token, 'password' => 'a-brand-new-pass-1'];

    $this->postJson('/api/v1/reset-password', $body)->assertOk();
    $this->postJson('/api/v1/reset-password', ['password' => 'another-new-pass-2'] + $body)->assertStatus(422)->assertJsonValidationErrors('token');
});

it('refuses a wrong token and keeps the old password', function () {
    $user = User::factory()->create();
    mailedToken($this, $user);

    $this->postJson('/api/v1/reset-password', ['email' => $user->email, 'token' => 'wrong-token', 'password' => 'a-brand-new-pass-1'])
        ->assertStatus(422)->assertJsonValidationErrors('token');

    expect(Hash::check('password', $user->refresh()->password))->toBeTrue();
});

it('refuses a token that belongs to someone else', function () {
    $mine = User::factory()->create();
    $other = User::factory()->create();
    $token = mailedToken($this, $mine);

    $this->postJson('/api/v1/reset-password', ['email' => $other->email, 'token' => $token, 'password' => 'a-brand-new-pass-1'])->assertStatus(422);

    expect(Hash::check('password', $other->refresh()->password))->toBeTrue();
});

it('refuses a weak new password', function () {
    $user = User::factory()->create();
    $token = mailedToken($this, $user);

    $this->postJson('/api/v1/reset-password', ['email' => $user->email, 'token' => $token, 'password' => 'short'])
        ->assertStatus(422)->assertJsonValidationErrors('password');
});

it('slows down someone who keeps asking', function () {
    $user = User::factory()->create();
    Notification::fake();

    foreach (range(1, 5) as $ignored) {
        $this->postJson('/api/v1/forgot-password', ['email' => $user->email])->assertOk();
    }

    $this->postJson('/api/v1/forgot-password', ['email' => $user->email])->assertStatus(429);
});
