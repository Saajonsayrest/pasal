<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Bill discount: subtotal - discount = total. The discount is also split over the lines,
        // so a later return knows what each line really cost the customer.
        Schema::table('sales', function (Blueprint $table) {
            $table->unsignedBigInteger('subtotal')->default(0)->after('customer_id');
            $table->unsignedBigInteger('discount')->default(0)->after('subtotal');
            $table->unsignedBigInteger('returned_total')->default(0)->after('paid'); // value sent back, VAT included
            $table->timestamp('cancelled_at')->nullable();
        });
        DB::statement('UPDATE sales SET subtotal = total');

        DB::statement('ALTER TABLE sales DROP CONSTRAINT sales_paid_within_total');
        DB::statement('ALTER TABLE sales ADD CONSTRAINT sales_discount_within_subtotal CHECK (discount <= subtotal AND total = subtotal - discount)');
        DB::statement('ALTER TABLE sales ADD CONSTRAINT sales_paid_within_net_total CHECK (returned_total <= total AND paid <= total - returned_total)');

        Schema::table('sale_items', function (Blueprint $table) {
            $table->unsignedBigInteger('discount')->default(0)->after('unit_cost');
            $table->unsignedInteger('returned_quantity')->default(0)->after('discount');
            $table->unsignedBigInteger('returned_amount')->default(0)->after('returned_quantity');
            $table->boolean('vat_applies')->default(false)->after('unit_cost'); // as it was on the day of the sale
        });
        DB::statement('UPDATE sale_items SET vat_applies = items.vat_applies FROM items WHERE items.id = sale_items.item_id');
        DB::statement('ALTER TABLE sale_items ADD CONSTRAINT sale_items_returned_within_sold CHECK (returned_quantity <= quantity)');

        // A return (or a full cancel) is its own row. VAT and reports count it on the day it happened,
        // not on the day of the sale, so a month that is already filed never changes.
        Schema::create('sale_returns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained();
            $table->foreignId('sale_id')->constrained();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('kind', 10); // return | cancel
            $table->timestamp('returned_at');
            $table->unsignedBigInteger('total');
            $table->unsignedBigInteger('taxable_amount')->default(0);
            $table->unsignedBigInteger('vat_amount')->default(0);
            $table->unsignedBigInteger('exempt_amount')->default(0);
            $table->unsignedBigInteger('cost')->default(0); // cost of the goods that came back
            $table->unsignedBigInteger('refunded')->default(0); // cash given back to the customer
            $table->boolean('restocked')->default(true);
            $table->string('note')->nullable();
            $table->timestamps();

            $table->index(['business_id', 'returned_at']);
            $table->index(['business_id', 'sale_id']);
        });

        Schema::create('sale_return_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained();
            $table->foreignId('sale_return_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sale_item_id')->constrained();
            $table->unsignedInteger('quantity');
            $table->unsignedBigInteger('amount');
            $table->timestamps();

            $table->index('business_id');
        });

        // Money going back to a customer is a payment too, with direction "refund".
        DB::statement('ALTER TABLE payments ALTER COLUMN direction TYPE varchar(10)');
        DB::statement('ALTER TABLE payments DROP CONSTRAINT payments_direction_matches');
        DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_direction_matches CHECK ((direction IN ('in', 'refund') AND sale_id IS NOT NULL AND purchase_id IS NULL) OR (direction = 'out' AND purchase_id IS NOT NULL AND sale_id IS NULL))");

        // null = no limit. 0 = no udhar at all.
        Schema::table('customers', function (Blueprint $table) {
            $table->unsignedBigInteger('credit_limit')->nullable()->after('pan');
        });

        Schema::table('payments', fn (Blueprint $t) => $t->index(['business_id', 'paid_at']));
    }

    public function down(): void
    {
        Schema::table('payments', fn (Blueprint $t) => $t->dropIndex(['business_id', 'paid_at']));
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('credit_limit'));

        DB::statement('DELETE FROM payments WHERE direction = \'refund\'');
        DB::statement('ALTER TABLE payments DROP CONSTRAINT payments_direction_matches');
        DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_direction_matches CHECK ((direction = 'in' AND sale_id IS NOT NULL AND purchase_id IS NULL) OR (direction = 'out' AND purchase_id IS NOT NULL AND sale_id IS NULL))");
        DB::statement('ALTER TABLE payments ALTER COLUMN direction TYPE varchar(3)');

        Schema::dropIfExists('sale_return_items');
        Schema::dropIfExists('sale_returns');

        DB::statement('ALTER TABLE sale_items DROP CONSTRAINT sale_items_returned_within_sold');
        Schema::table('sale_items', fn (Blueprint $t) => $t->dropColumn(['discount', 'returned_quantity', 'returned_amount', 'vat_applies']));

        DB::statement('ALTER TABLE sales DROP CONSTRAINT sales_paid_within_net_total');
        DB::statement('ALTER TABLE sales DROP CONSTRAINT sales_discount_within_subtotal');
        DB::statement('ALTER TABLE sales ADD CONSTRAINT sales_paid_within_total CHECK (paid <= total)');
        Schema::table('sales', fn (Blueprint $t) => $t->dropColumn(['subtotal', 'discount', 'returned_total', 'cancelled_at']));
    }
};
