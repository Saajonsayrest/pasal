<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\ItemResource;
use App\Models\Item;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Owner only. One photo per item, kept on the public disk under a random name.
 * The file name from the client is never used, and only real images of a small size are accepted.
 */
class ItemPhotoController extends Controller
{
    public function store(Request $request, Item $item): ItemResource
    {
        $request->validate([
            'photo' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'], // KB
        ]);

        $old = $item->photo_path;
        $item->photo_path = $request->file('photo')->store("items/{$item->business_id}", 'public');
        $item->save();

        if ($old) {
            Storage::disk('public')->delete($old);
        }

        return new ItemResource($item);
    }

    public function destroy(Item $item): ItemResource
    {
        if ($item->photo_path) {
            Storage::disk('public')->delete($item->photo_path);
            $item->photo_path = null;
            $item->save();
        }

        return new ItemResource($item);
    }
}
