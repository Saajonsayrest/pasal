<?php

use Illuminate\Support\Facades\Route;

function openApiDocument(): array
{
    return json_decode(file_get_contents(base_path('../docs/openapi.json')), true, flags: JSON_THROW_ON_ERROR);
}

it('has docs/openapi.json up to date with the routes', function () {
    // If this fails, run: php artisan pasal:openapi
    $this->artisan('pasal:openapi --check')->assertSuccessful();
});

it('describes every API route once, with unique operation ids', function () {
    $doc = openApiDocument();
    $found = [];
    $ids = [];
    foreach ($doc['paths'] as $path => $operations) {
        foreach ($operations as $method => $operation) {
            $found[] = strtoupper($method).' '.$path;
            $ids[] = $operation['operationId'];
            expect($operation['responses'])->not->toBeEmpty();
            expect($operation['summary'])->not->toBeEmpty();
        }
    }

    $expected = [];
    foreach (Route::getRoutes()->getRoutes() as $route) {
        if (! str_starts_with($route->uri(), 'api/v1')) {
            continue;
        }
        $methods = array_diff($route->methods(), ['HEAD']);
        in_array('PUT', $methods, true) && $methods = array_diff($methods, ['PATCH']);
        foreach ($methods as $method) {
            $expected[] = $method.' '.substr($route->uri(), strlen('api/v1'));
        }
    }

    expect($found)->toEqualCanonicalizing($expected);
    expect($ids)->toEqual(array_unique($ids));
});

it('marks the public routes, the owner routes and the safe-retry header', function () {
    $paths = openApiDocument()['paths'];

    expect($paths['/login']['post']['security'])->toBe([]);
    expect($paths['/sales']['get']['security'])->toBe([['bearerAuth' => []]]);
    expect($paths['/cash-book']['get']['x-owner-only'])->toBeTrue();
    expect($paths['/sales']['get'])->not->toHaveKey('x-owner-only');

    $headers = collect($paths['/sales']['post']['parameters'])->where('in', 'header')->pluck('name');
    expect($headers)->toContain('Idempotency-Key');
});

it('reads request fields from the validation rules, including nested lines', function () {
    $schema = openApiDocument()['paths']['/sales']['post']['requestBody']['content']['application/json']['schema'];

    expect($schema['required'])->toBe(['items']);
    expect($schema['properties']['items']['type'])->toBe('array');
    expect($schema['properties']['items']['items']['required'])->toBe(['item_id', 'quantity']);
    expect($schema['properties']['items']['items']['properties']['quantity']['minimum'])->toBe(1);
});
