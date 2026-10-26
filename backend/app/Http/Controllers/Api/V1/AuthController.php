<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\PasswordRequest;
use App\Http\Resources\Api\V1\BusinessResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

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
