<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StockCountRequest;
use App\Models\Item;
use App\Services\StockService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/** Owner only. Walk the shelves, type what you counted, and the system catches up. */
class StockCountController extends Controller
{
    public function store(StockCountRequest $request, StockService $stock): JsonResponse
    {
        $lines = collect($request->validated('items'))->sortBy('item_id')->values(); // same lock order every time
        $note = $request->validated('note') ?? 'Stock count';
        $items = Item::whereIn('id', $lines->pluck('item_id'))->get()->keyBy('id');

        $rows = DB::transaction(fn () => $lines->map(function ($line) use ($stock, $items, $note, $request) {
            $item = $items[$line['item_id']];

            return ['item_id' => $item->id, 'item_name' => $item->name]
                + $stock->count($item, (int) $line['counted'], $request->user()->id, $note);
        }));

        return response()->json([
            'data' => $rows,
            'items_changed' => $rows->where('difference', '!=', 0)->count(),
        ], 201);
    }
}
