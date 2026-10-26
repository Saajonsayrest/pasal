<?php

use App\Models\IdempotencyKey;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Expired login tokens pile up in the database. Remove them once a day.
Schedule::command('sanctum:prune-expired --hours=24')->daily();

// Saved answers for Idempotency-Key are kept one day.
Schedule::command('model:prune', ['--model' => [IdempotencyKey::class]])->daily();
