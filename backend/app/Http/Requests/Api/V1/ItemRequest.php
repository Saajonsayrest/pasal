<?php

namespace App\Http\Requests\Api\V1;

use App\Models\Item;
use App\Support\CurrentBusiness;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class ItemRequest extends FormRequest
{
    /** The item that already uses the name, when the name check fails. */
    private ?Item $sameName = null;

    public function authorize(): bool
    {
        return true;
    }

    /** Names are compared without extra spaces and without caring about capital letters. */
    protected function prepareForValidation(): void
    {
        $clean = [];

        if (is_string($this->input('name'))) {
            $clean['name'] = trim((string) preg_replace('/\s+/u', ' ', $this->input('name')));
        }
        if (is_string($this->input('sku'))) {
            $clean['sku'] = trim($this->input('sku')) === '' ? null : trim($this->input('sku'));
        }

        $this->merge($clean);
    }

    /**
     * Quantity is not here. Stock changes only through purchases, sales and adjustments.
     *
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'category_id' => ['nullable', 'integer', CurrentBusiness::exists('categories')],
            'name' => ['required', 'string', 'max:150', function (string $attribute, mixed $value, \Closure $fail) {
                // Item has the business filter, so this only looks at the caller's own items.
                $current = $this->route('item');
                $found = Item::withTrashed()
                    ->whereRaw('lower(name) = ?', [mb_strtolower((string) $value)])
                    ->when($current, fn ($q) => $q->whereKeyNot($current instanceof Item ? $current->getKey() : $current))
                    ->get()
                    ->sortBy(fn (Item $i) => $i->trashed() ? 1 : 0) // an active item wins over a deleted one
                    ->first();

                if ($found) {
                    $this->sameName = $found;
                    $fail($found->trashed()
                        ? "An item named \"{$found->name}\" was deleted earlier. Restore it instead of making a new one."
                        : "An item named \"{$found->name}\" already exists. Use that item instead.");
                }
            }],
            'sku' => ['nullable', 'string', 'max:50', CurrentBusiness::unique('items', 'sku')->ignore($this->route('item'))],
            'unit' => ['nullable', 'string', 'max:20'],
            'vat_applies' => ['nullable', 'boolean'],
            'cost_price' => ['required', 'integer', 'min:0', 'max:10000000000'],
            'sell_price' => ['required', 'integer', 'min:0', 'max:10000000000'],
            'low_stock_at' => ['nullable', 'integer', 'min:0', 'max:1000000'],
        ];
    }

    /** Same error shape as everywhere, plus a pointer to the item that already has this name. */
    protected function failedValidation(Validator $validator): void
    {
        $body = ['message' => $validator->errors()->first(), 'errors' => $validator->errors()->messages()];

        if ($this->sameName) {
            $body['existing_item'] = ['id' => $this->sameName->id, 'name' => $this->sameName->name, 'deleted' => $this->sameName->trashed()];
        }

        throw new HttpResponseException(response()->json($body, 422));
    }
}
