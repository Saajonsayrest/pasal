<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StockAdjustmentRequest;
use App\Http\Resources\Api\V1\ItemResource;
use App\Models\Item;
use App\Services\StockService;

class StockAdjustmentController extends Controller
{
    public function store(StockAdjustmentRequest $request, StockService $stock): ItemResource
    {
        $item = Item::findOrFail($request->validated('item_id'));

        $stock->move($item, $request->validated('change'), 'adjust', $request->user()->id, null, $request->validated('note'));

        return new ItemResource($item->refresh());
    }
}
