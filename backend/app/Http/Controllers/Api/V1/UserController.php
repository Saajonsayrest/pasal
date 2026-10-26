<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\UserRequest;
use App\Http\Resources\Api\V1\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The owner manages the people of their own business. User is not scoped by a global scope
 * (login must find users before anyone is signed in), so every query here filters by business.
 */
class UserController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return UserResource::collection(
            User::where('business_id', $request->user()->business_id)->orderBy('name')->paginate(50)
        );
    }

    public function store(UserRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = new User(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password']]);
        $user->business_id = $request->user()->business_id;
        $user->role = $data['role'];
        $user->save();

        return (new UserResource($user))->response()->setStatusCode(201);
    }

    public function update(UserRequest $request, int $user): UserResource|JsonResponse
    {
        $target = User::where('business_id', $request->user()->business_id)->findOrFail($user);
        $data = $request->validated();

        if (isset($data['role']) && $target->is($request->user()) && $data['role'] !== $target->role) {
            return response()->json(['message' => 'You cannot change your own role.', 'errors' => ['role' => ['You cannot change your own role.']]], 422);
        }

        $target->fill(collect($data)->only(['name', 'email', 'password'])->all());
        if (isset($data['role'])) {
            $target->role = $data['role'];
        }
        $target->save();

        // A new password or a new role signs that person out everywhere.
        if (isset($data['password']) || isset($data['role'])) {
            $target->tokens()->delete();
        }

        return new UserResource($target);
    }

    public function destroy(Request $request, int $user): JsonResponse
    {
        $target = User::where('business_id', $request->user()->business_id)->findOrFail($user);

        if ($target->is($request->user())) {
            return response()->json(['message' => 'You cannot delete yourself.'], 422);
        }

        $target->tokens()->delete();
        $target->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
