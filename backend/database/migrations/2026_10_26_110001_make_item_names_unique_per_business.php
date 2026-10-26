<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // A SKU or barcode is optional. Many items may have none (NULLs never clash in a unique index).
        DB::statement('ALTER TABLE items ALTER COLUMN sku DROP NOT NULL');

        // Inside one business a name is used once, ignoring capital letters. Deleted items do not count,
        // so a deleted name can be used again. The database enforces this even if the app has a bug.
        DB::statement('CREATE UNIQUE INDEX items_business_name_unique ON items (business_id, lower(name)) WHERE deleted_at IS NULL');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS items_business_name_unique');
        DB::statement("UPDATE items SET sku = 'ITEM-'||id WHERE sku IS NULL");
        DB::statement('ALTER TABLE items ALTER COLUMN sku SET NOT NULL');
    }
};
