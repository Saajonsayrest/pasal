<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\PasswordRequest;
use App\Http\Requests\Api\V1\ResetPasswordRequest;
use App\Http\Resources\Api\V1\BusinessResource;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->validated('email'))->first();

        if (! $user || ! Hash::check($request->validated('password'), $user->password)) {
            Log::warning('Failed login', ['email' => $request->validated('email'), 'ip' => $request->ip()]);

            return response()->json([
                'message' => 'Email or password is wrong.',
                'errors' => ['email' => ['Email or password is wrong.']],
            ], 422);
        }

        $token = $user->createToken(
            $request->validated('device_name') ?? 'mobile',
            ['*'],
            now()->addDays(30),
        );

        return response()->json(['token' => $token->plainTextToken, 'user' => $this->profile($user)]);
    }

    /**
     * Sends a reset link to the email. The answer is the same whether the email exists or not,
     * so nobody can use this to find out who has an account.
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        Password::sendResetLink(['email' => $request->validated('email')]);

        return response()->json(['message' => 'If this email has an account, a reset link was sent.']);
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset($request->validated(), function (User $user, string $password) {
            $user->forceFill(['password' => $password, 'remember_token' => Str::random(60)])->save();
            $user->tokens()->delete(); // every phone must sign in again with the new password
            event(new PasswordReset($user));
        });

        if ($status !== Password::PASSWORD_RESET) {
            Log::warning('Failed password reset', ['email' => $request->validated('email'), 'ip' => $request->ip(), 'status' => $status]);

            return response()->json([
                'message' => 'This reset link is wrong or has expired. Ask for a new one.',
                'errors' => ['token' => ['This reset link is wrong or has expired. Ask for a new one.']],
            ], 422);
        }

        return response()->json(['message' => 'Password changed. Sign in with the new password.']);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    /** For a lost phone: every token of this user stops working. */
    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return response()->json(['message' => 'Logged out on all devices.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json($this->profile($request->user()));
    }

    public function changePassword(PasswordRequest $request): JsonResponse
    {
        $user = $request->user();

        if (! Hash::check($request->validated('current_password'), $user->password)) {
            return response()->json([
                'message' => 'Current password is wrong.',
                'errors' => ['current_password' => ['Current password is wrong.']],
            ], 422);
        }

        $user->update(['password' => $request->validated('password')]);

        // Keep this device signed in, sign out every other device.
        $user->tokens()->where('id', '!=', $user->currentAccessToken()->id)->delete();

        return response()->json(['message' => 'Password changed.']);
    }

    /**
     * @return array<string, mixed>
     */
    private function profile(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'business' => (new BusinessResource($user->business))->resolve(),
        ];
    }
}
