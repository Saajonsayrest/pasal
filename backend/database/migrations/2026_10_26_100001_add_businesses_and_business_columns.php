<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** Every table that holds a business's own data. */
    private array $businessTables = [
        'categories', 'items', 'suppliers', 'customers', 'stock_movements',
        'sales', 'sale_items', 'purchases', 'purchase_items', 'payments', 'expenses', 'vat_filings',
    ];

    public function up(): void
    {
        // This migration adds NOT NULL columns. It is only safe on empty tables.
        // With real data, first create a business and backfill business_id by hand.
        foreach (array_merge($this->businessTables, ['users']) as $table) {
            if (DB::table($table)->exists()) {
                throw new RuntimeException("Table {$table} has rows. Backfill business_id before running this migration.");
            }
        }

        Schema::create('businesses', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('pan', 20)->nullable();
            $table->string('phone', 30)->nullable();
            $table->string('address')->nullable();
            $table->decimal('vat_rate', 5, 2)->default(13);
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('business_id')->after('id')->constrained();
            $table->string('role', 10)->default('staff')->after('email'); // owner | staff
        });

        foreach ($this->businessTables as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->foreignId('business_id')->after('id')->constrained();
            });
        }

        // Unique values are now unique inside one business, not across all of them.
        Schema::table('items', function (Blueprint $table) {
            $table->dropUnique(['sku']);
            $table->unique(['business_id', 'sku']);
            $table->index(['business_id', 'name']);
        });
        Schema::table('categories', function (Blueprint $table) {
            $table->dropUnique(['name']);
            $table->unique(['business_id', 'name']);
        });
        Schema::table('vat_filings', function (Blueprint $table) {
            $table->dropUnique(['period']);
            $table->unique(['business_id', 'period']);
            $table->index(['business_id', 'period_to']);
        });

        // Every list starts with "this business", so each index starts with business_id.
        Schema::table('customers', fn (Blueprint $t) => $t->index(['business_id', 'name']));
        Schema::table('suppliers', fn (Blueprint $t) => $t->index(['business_id', 'name']));
        Schema::table('sales', function (Blueprint $t) {
            $t->index(['business_id', 'sold_at']);
            $t->index(['business_id', 'customer_id']);
        });
        Schema::table('purchases', function (Blueprint $t) {
            $t->index(['business_id', 'bought_at']);
            $t->index(['business_id', 'supplier_id']);
        });
        Schema::table('expenses', fn (Blueprint $t) => $t->index(['business_id', 'spent_at']));
        Schema::table('stock_movements', fn (Blueprint $t) => $t->index(['business_id', 'item_id']));
        Schema::table('payments', function (Blueprint $t) {
            $t->index(['business_id', 'sale_id']);
            $t->index(['business_id', 'purchase_id']);
        });
        Schema::table('sale_items', fn (Blueprint $t) => $t->index('business_id'));
        Schema::table('purchase_items', fn (Blueprint $t) => $t->index('business_id'));
        Schema::table('users', fn (Blueprint $t) => $t->index('business_id'));
    }

    public function down(): void
    {
        Schema::table('vat_filings', function (Blueprint $table) {
            $table->dropUnique(['business_id', 'period']);
            $table->dropIndex(['business_id', 'period_to']);
        });
        Schema::table('categories', fn (Blueprint $t) => $t->dropUnique(['business_id', 'name']));
        Schema::table('items', function (Blueprint $table) {
            $table->dropUnique(['business_id', 'sku']);
            $table->dropIndex(['business_id', 'name']);
        });

        foreach (array_reverse($this->businessTables) as $name) {
            Schema::table($name, fn (Blueprint $t) => $t->dropConstrainedForeignId('business_id'));
        }

        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('business_id');
            $table->dropColumn('role');
        });

        Schema::table('categories', fn (Blueprint $t) => $t->unique('name'));
        Schema::table('items', fn (Blueprint $t) => $t->unique('sku'));
        Schema::table('vat_filings', fn (Blueprint $t) => $t->unique('period'));

        Schema::dropIfExists('businesses');
    }
};
