<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One row per Idempotency-Key a client sent. The saved answer is sent again if the same request comes twice.
        Schema::create('idempotency_keys', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained()->cascadeOnDelete();
            $table->string('key', 100);
            $table->string('request_hash', 64); // user, method, path and body, so a reused key with other data is caught
            $table->unsignedSmallInteger('status')->nullable(); // null while the first request is still running
            $table->text('body')->nullable();
            $table->timestamps();

            $table->unique(['business_id', 'key']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('idempotency_keys');
    }
};
