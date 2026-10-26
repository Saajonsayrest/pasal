<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Item;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Owner only. Every change to one item's stock, newest first. */
class StockMovementController extends Controller
{
    public function index(Request $request, Item $item): JsonResponse
    {
        $page = $item->movements()
            ->with('user:id,name')
            ->latest('id')
            ->paginate(min((int) $request->query('per_page', 30), 100));

        return response()->json([
            'item' => ['id' => $item->id, 'name' => $item->name, 'quantity' => $item->quantity],
            'data' => $page->getCollection()->map(fn ($m) => [
                'id' => $m->id,
                'change' => $m->change,
                'reason' => $m->reason, // sale, sale_return, sale_cancel, purchase, adjust, count
                'ref_type' => $m->ref_type ? strtolower(class_basename($m->ref_type)) : null,
                'ref_id' => $m->ref_id,
                'note' => $m->note,
                'by' => $m->user?->name,
                'at' => $m->created_at?->toIso8601String(),
            ]),
            'links' => ['next' => $page->nextPageUrl(), 'prev' => $page->previousPageUrl()],
            'meta' => ['current_page' => $page->currentPage(), 'per_page' => $page->perPage(), 'total' => $page->total()],
        ]);
    }
}
