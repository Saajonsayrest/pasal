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
    /**
     * A stock count: the shelf says $counted, the system says something else. Fix the system.
     * Writes a "count" history row only when the two differ.
     *
     * @return array{system: int, counted: int, difference: int}
     */
    public function count(Item $item, int $counted, ?int $userId, ?string $note = null): array
    {
        return DB::transaction(function () use ($item, $counted, $userId, $note) {
            $system = (int) Item::withTrashed()->whereKey($item->id)->lockForUpdate()->firstOrFail()->quantity;
            $difference = $counted - $system;

            if ($difference !== 0) {
                $this->move($item, $difference, 'count', $userId, null, $note);
            }

            return ['system' => $system, 'counted' => $counted, 'difference' => $difference];
        });
    }

    public function move(Item $item, int $change, string $reason, ?int $userId, ?Model $ref = null, ?string $note = null): StockMovement
    {
        return DB::transaction(function () use ($item, $change, $reason, $userId, $ref, $note) {
            // Lock the row so two sales at once cannot both take the last item.
            // Withtrashed: goods of a deleted item can still come back in a sale return.
            $locked = Item::withTrashed()->whereKey($item->id)->lockForUpdate()->firstOrFail();

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
