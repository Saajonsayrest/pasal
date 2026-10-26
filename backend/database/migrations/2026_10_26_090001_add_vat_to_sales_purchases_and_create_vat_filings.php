<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('items', function (Blueprint $table) {
            $table->boolean('vat_applies')->default(true)->after('unit');
        });

        Schema::table('customers', function (Blueprint $table) {
            $table->string('pan', 20)->nullable()->after('address');
        });

        Schema::table('suppliers', function (Blueprint $table) {
            $table->string('pan', 20)->nullable()->after('address');
        });

        // Sale prices include VAT. These columns split the total into its parts.
        Schema::table('sales', function (Blueprint $table) {
            $table->string('bill_no', 50)->nullable()->index();
            $table->decimal('vat_rate', 5, 2)->default(0);
            $table->unsignedBigInteger('taxable_amount')->default(0); // VAT items, without VAT
            $table->unsignedBigInteger('vat_amount')->default(0);
            $table->unsignedBigInteger('exempt_amount')->default(0); // items with no VAT
        });

        // Purchase unit costs are without VAT. vat_amount is copied from the supplier's bill.
        Schema::table('purchases', function (Blueprint $table) {
            $table->string('bill_no', 50)->nullable()->index();
            $table->date('bill_date')->nullable();
            $table->unsignedBigInteger('vat_amount')->default(0);
        });

        Schema::create('vat_filings', function (Blueprint $table) {
            $table->id();
            $table->string('period', 20)->unique(); // label you choose, e.g. 2083-07
            $table->date('period_from');
            $table->date('period_to');
            $table->string('source', 10)->default('computed'); // computed | manual (old return typed in)
            $table->unsignedBigInteger('sales_taxable')->default(0);
            $table->unsignedBigInteger('sales_exempt')->default(0);
            $table->unsignedBigInteger('output_vat')->default(0);
            $table->unsignedBigInteger('purchases_taxable')->default(0);
            $table->unsignedBigInteger('input_vat')->default(0);
            $table->unsignedBigInteger('carry_in')->default(0);
            $table->unsignedBigInteger('payable')->default(0);
            $table->unsignedBigInteger('carry_out')->default(0);
            $table->date('filed_on')->nullable();
            $table->unsignedBigInteger('paid_amount')->default(0);
            $table->date('paid_on')->nullable();
            $table->string('receipt_no', 60)->nullable();
            $table->text('note')->nullable();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vat_filings');
        Schema::table('purchases', fn (Blueprint $t) => $t->dropColumn(['bill_no', 'bill_date', 'vat_amount']));
        Schema::table('sales', fn (Blueprint $t) => $t->dropColumn(['bill_no', 'vat_rate', 'taxable_amount', 'vat_amount', 'exempt_amount']));
        Schema::table('suppliers', fn (Blueprint $t) => $t->dropColumn('pan'));
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('pan'));
        Schema::table('items', fn (Blueprint $t) => $t->dropColumn('vat_applies'));
    }
};
