<?php

namespace App\Http\Requests\Api\V1;

use App\Support\CurrentBusiness;
use Illuminate\Foundation\Http\FormRequest;

class CategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100', CurrentBusiness::unique('categories', 'name')->ignore($this->route('category'))],
            'icon' => ['nullable', 'string', 'max:40', 'regex:/^[a-z0-9_]+$/'],
            'color' => ['nullable', 'string', 'regex:/^#[0-9a-fA-F]{6}$/'],
        ];
    }
}
