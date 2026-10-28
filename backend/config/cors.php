<?php

return [
    'paths' => ['api/*'],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],

    // Browser origins that may call the API, comma separated in .env. Empty means no browser site is allowed.
    // The phone app does not use CORS. The Mac app (Tauri) is a web view, so its origin `tauri://localhost` must be listed.
    'allowed_origins' => array_values(array_filter(array_map('trim', explode(',', (string) env('PASAL_CORS_ORIGINS', ''))))),

    'allowed_origins_patterns' => [],

    // Idempotency-Key is sent by the website on every POST that saves a sale, payment or stock change.
    'allowed_headers' => ['Authorization', 'Content-Type', 'Accept', 'Idempotency-Key'],

    'exposed_headers' => ['Idempotent-Replayed', 'Retry-After'],

    'max_age' => 600,

    // We use Bearer tokens, not cookies.
    'supports_credentials' => false,
];
