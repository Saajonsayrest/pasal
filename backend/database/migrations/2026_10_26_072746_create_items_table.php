<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->string('sku')->unique();
            $table->string('unit', 20)->default('pcs');
            // Money is stored as whole paisa so we never use decimals.
            $table->unsignedBigInteger('cost_price')->default(0);
            $table->unsignedBigInteger('sell_price')->default(0);
            $table->integer('quantity')->default(0);
            $table->unsignedInteger('low_stock_at')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });

        DB::statement('ALTER TABLE items ADD CONSTRAINT items_quantity_not_negative CHECK (quantity >= 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('items');
    }
};
