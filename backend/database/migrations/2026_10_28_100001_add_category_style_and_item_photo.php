<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Category look (Cashew style): an icon name (Material Symbols) and a colour.
        Schema::table('categories', function (Blueprint $table) {
            $table->string('icon', 40)->nullable()->after('name');
            $table->string('color', 7)->nullable()->after('icon');
        });

        // Item photo: a path on the public disk, never a user supplied file name.
        Schema::table('items', function (Blueprint $table) {
            $table->string('photo_path', 255)->nullable()->after('low_stock_at');
        });
    }

    public function down(): void
    {
        Schema::table('items', fn (Blueprint $table) => $table->dropColumn('photo_path'));
        Schema::table('categories', fn (Blueprint $table) => $table->dropColumn(['icon', 'color']));
    }
};
