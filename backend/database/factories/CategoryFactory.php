<?php

namespace Database\Factories;

use App\Models\Category;
use App\Support\CurrentBusiness;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Category>
 */
class CategoryFactory extends Factory
{
    public function definition(): array
    {
        return ['business_id' => fn () => CurrentBusiness::idOrCreate(), 'name' => fake()->unique()->word()];
    }
}
