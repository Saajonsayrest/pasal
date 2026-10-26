<?php

namespace Database\Factories;

use App\Models\Customer;
use App\Support\CurrentBusiness;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Customer>
 */
class CustomerFactory extends Factory
{
    public function definition(): array
    {
        return ['business_id' => fn () => CurrentBusiness::idOrCreate(), 'name' => fake()->name(), 'phone' => fake()->numerify('98########')];
    }
}
