<?php

return [
    'paths' => ['api/*'],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],

    // Browser origins that may call the API, comma separated in .env. Empty means no browser site is allowed.
    // The phone app and the Mac app do not use CORS, so they work either way.
    'allowed_origins' => array_values(array_filter(array_map('trim', explode(',', (string) env('PASAL_CORS_ORIGINS', ''))))),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['Authorization', 'Content-Type', 'Accept'],

    'exposed_headers' => [],

    'max_age' => 600,

    // We use Bearer tokens, not cookies.
    'supports_credentials' => false,
];
