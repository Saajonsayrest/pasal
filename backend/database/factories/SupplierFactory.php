<?php

namespace Database\Factories;

use App\Models\Supplier;
use App\Support\CurrentBusiness;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Supplier>
 */
class SupplierFactory extends Factory
{
    public function definition(): array
    {
        return ['business_id' => fn () => CurrentBusiness::idOrCreate(), 'name' => fake()->company(), 'phone' => fake()->numerify('98########')];
    }
}
