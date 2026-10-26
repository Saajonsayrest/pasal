<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->string('direction', 3); // in = money from a customer, out = money to a supplier
            $table->foreignId('sale_id')->nullable()->constrained();
            $table->foreignId('purchase_id')->nullable()->constrained();
            $table->unsignedBigInteger('amount');
            $table->timestamp('paid_at');
            $table->string('method', 20)->default('cash');
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
        });

        DB::statement('ALTER TABLE payments ADD CONSTRAINT payments_amount_positive CHECK (amount > 0)');
        DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_direction_matches CHECK ((direction = 'in' AND sale_id IS NOT NULL AND purchase_id IS NULL) OR (direction = 'out' AND purchase_id IS NOT NULL AND sale_id IS NULL))");

        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('category', 50)->nullable();
            $table->unsignedBigInteger('amount');
            $table->timestamp('spent_at');
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
        Schema::dropIfExists('payments');
    }
};
