<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * On create everything is required. On update (PATCH) every field is optional.
     * A login email is unique across the whole system, because one email means one business.
     *
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');
        $required = $creating ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:100'],
            'email' => [$required, 'email', 'max:150', Rule::unique('users', 'email')->ignore($this->route('user'))],
            'password' => [$required, 'string', Password::min(10)->max(100)],
            'role' => [$required, Rule::in(['owner', 'staff'])],
        ];
    }
}
