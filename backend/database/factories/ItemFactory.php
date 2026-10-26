<?php

namespace Database\Factories;

use App\Models\Item;
use App\Support\CurrentBusiness;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Item>
 */
class ItemFactory extends Factory
{
    public function definition(): array
    {
        return [
            'business_id' => fn () => CurrentBusiness::idOrCreate(),
            'name' => fake()->unique()->bothify('Item ??? ####'),
            'sku' => strtoupper(fake()->unique()->bothify('??-####')),
            'unit' => 'pcs',
            'cost_price' => 10000,
            'sell_price' => 12000,
            'quantity' => 10,
            'low_stock_at' => 3,
        ];
    }
}
