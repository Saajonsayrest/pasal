<?php

namespace App\Services;

use App\Models\Item;
use App\Models\StockMovement;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The only place that changes stock. It writes one history row and updates
 * the quantity in the same database transaction, so the two never disagree.
 */
class StockService
{
    public function move(Item $item, int $change, string $reason, ?int $userId, ?Model $ref = null, ?string $note = null): StockMovement
    {
        return DB::transaction(function () use ($item, $change, $reason, $userId, $ref, $note) {
            // Lock the row so two sales at once cannot both take the last item.
            $locked = Item::whereKey($item->id)->lockForUpdate()->firstOrFail();

            if ($locked->quantity + $change < 0) {
                throw ValidationException::withMessages([
                    'quantity' => ["Not enough stock for {$locked->name}. Only {$locked->quantity} left."],
                ]);
            }

            $locked->quantity += $change;
            $locked->save();
            $item->quantity = $locked->quantity;

            return StockMovement::create([
                'item_id' => $locked->id,
                'change' => $change,
                'reason' => $reason,
                'ref_type' => $ref?->getMorphClass(),
                'ref_id' => $ref?->getKey(),
                'user_id' => $userId,
                'note' => $note,
            ]);
        });
    }
}
