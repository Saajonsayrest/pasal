<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ItemRequest;
use App\Http\Resources\Api\V1\ItemResource;
use App\Models\Item;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ItemController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $onlyDeleted = $request->query('trashed') === 'only';
        abort_if($onlyDeleted && ! $request->user()->isOwner(), 403, 'Only the owner can do this.');

        $items = Item::query()
            ->when($onlyDeleted, fn ($q) => $q->onlyTrashed())
            ->when($request->boolean('low_stock'), fn ($q) => $q->lowStock())
            ->when($request->query('category_id'), fn ($q, $id) => $q->where('category_id', $id))
            ->when($request->query('search'), function ($q, $term) {
                $like = '%'.addcslashes($term, '%_\\').'%';
                $q->where(fn ($w) => $w->where('name', 'ilike', $like)->orWhere('sku', 'ilike', $like));
            })
            ->orderBy('name')
            ->paginate(min((int) $request->query('per_page', 20), 50));

        return ItemResource::collection($items);
    }

    /**
     * Type-ahead for names. Returns the items of your own business that match, names that
     * start with the text first. Use it before creating an item, so a name is reused.
     */
    public function suggest(Request $request): AnonymousResourceCollection
    {
        $text = trim((string) $request->query('q', ''));

        if ($text === '') {
            return ItemResource::collection(collect());
        }

        $escaped = addcslashes($text, '%_\\');

        $items = Item::query()
            ->where('name', 'ilike', '%'.$escaped.'%')
            ->orderByRaw('CASE WHEN lower(name) LIKE ? THEN 0 ELSE 1 END', [mb_strtolower($escaped).'%'])
            ->orderBy('name')
            ->limit(min(max((int) $request->query('limit', 10), 1), 20))
            ->get();

        return ItemResource::collection($items);
    }

    public function store(ItemRequest $request): JsonResponse
    {
        $item = Item::create($request->validated());

        return (new ItemResource($item->refresh()))->response()->setStatusCode(201);
    }

    public function show(Item $item): ItemResource
    {
        return new ItemResource($item);
    }

    public function update(ItemRequest $request, Item $item): ItemResource
    {
        $item->update($request->validated());

        return new ItemResource($item);
    }

    public function destroy(Item $item): JsonResponse
    {
        if ($item->quantity > 0) {
            $message = "{$item->name} still has {$item->quantity} in stock. Fix the stock to 0 first, so the stock value is not lost.";

            return response()->json(['message' => $message, 'errors' => ['quantity' => [$message]]], 422);
        }

        $item->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** Bring a deleted item back with all its history. */
    public function restore(int $item): JsonResponse|ItemResource
    {
        $deleted = Item::onlyTrashed()->findOrFail($item);

        $nameTaken = Item::whereRaw('lower(name) = ?', [mb_strtolower($deleted->name)])->exists();
        if ($nameTaken) {
            $message = "Another item is already called \"{$deleted->name}\". Rename or delete it first.";

            return response()->json(['message' => $message, 'errors' => ['name' => [$message]]], 422);
        }

        $deleted->restore();

        return new ItemResource($deleted);
    }
}
