<?php

namespace App\Http\Middleware;

use App\Models\IdempotencyKey;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * A POST that carries an Idempotency-Key header is saved at most once per business.
 * Send the same request again (bad network, double tap, retry) and you get the first answer back.
 *
 * The key is claimed and the work is done in ONE database transaction. If the work fails,
 * the claim goes away with it, so the client can retry with the same key. A second request
 * with the same key waits at the database until the first one finishes.
 */
class Idempotent
{
    public function handle(Request $request, Closure $next): Response
    {
        $key = $request->header('Idempotency-Key');

        if (! $request->isMethod('POST') || $key === null) {
            return $next($request);
        }

        if (! preg_match('/^[A-Za-z0-9._:\-]{8,100}$/', $key)) {
            return response()->json([
                'message' => 'Idempotency-Key must be 8 to 100 letters, digits or . _ : -',
                'errors' => ['idempotency_key' => ['Idempotency-Key must be 8 to 100 letters, digits or . _ : -']],
            ], 422);
        }

        $businessId = $request->user()->business_id;
        $hash = hash('sha256', implode('|', [$request->user()->id, $request->path(), $request->getContent()]));

        return DB::transaction(function () use ($request, $next, $key, $businessId, $hash) {
            $claimed = DB::table('idempotency_keys')->insertOrIgnore([
                'business_id' => $businessId,
                'key' => $key,
                'request_hash' => $hash,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            if ($claimed === 0) {
                return $this->replay(IdempotencyKey::where('business_id', $businessId)->where('key', $key)->firstOrFail(), $hash);
            }

            $response = $next($request);

            if ($response->isSuccessful()) {
                DB::table('idempotency_keys')->where('business_id', $businessId)->where('key', $key)
                    ->update(['status' => $response->getStatusCode(), 'body' => $response->getContent(), 'updated_at' => now()]);
            } else {
                // A refused request saved nothing, so the same key may be used again.
                DB::table('idempotency_keys')->where('business_id', $businessId)->where('key', $key)->delete();
            }

            return $response;
        });
    }

    private function replay(IdempotencyKey $saved, string $hash): Response
    {
        if (! hash_equals($saved->request_hash, $hash)) {
            return response()->json([
                'message' => 'This Idempotency-Key was already used for a different request.',
                'errors' => ['idempotency_key' => ['This Idempotency-Key was already used for a different request.']],
            ], 422);
        }

        return response($saved->body, $saved->status, ['Content-Type' => 'application/json', 'Idempotent-Replayed' => 'true']);
    }
}
