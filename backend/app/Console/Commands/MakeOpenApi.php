<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Request;
use Illuminate\Routing\Route;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route as Router;
use Illuminate\Support\Str;
use ReflectionMethod;
use ReflectionNamedType;
use Stringable;
use Throwable;

/**
 * Writes docs/openapi.json from the real routes and the validation rules of the form requests,
 * so the API description cannot drift from the code. `--check` fails when the file is out of date.
 * Response bodies are described only in outline: docs/api-reference.md has the details.
 */
class MakeOpenApi extends Command
{
    protected $signature = 'pasal:openapi {--path= : Where to write the file} {--check : Fail if the file is out of date}';

    protected $description = 'Write the OpenAPI description of the API (docs/openapi.json).';

    private const PREFIX = 'api/v1';

    /** Summaries for routes that are not plain list, show, create, update or delete. */
    private const SUMMARIES = [
        'POST /login' => 'Log in and get a token',
        'POST /logout' => 'Delete the token that sent this request',
        'POST /logout-all' => 'Delete every token of this user',
        'GET /me' => 'Show the logged-in user and shop',
        'POST /me/password' => 'Change the password of the logged-in user',
        'POST /forgot-password' => 'Email a password reset link',
        'POST /reset-password' => 'Set a new password with the emailed token',
        'GET /items/suggest' => 'Suggest item names while typing',
        'POST /items/{item}/photo' => 'Upload the photo of an item',
        'DELETE /items/{item}/photo' => 'Remove the photo of an item',
        'POST /items/{item}/restore' => 'Bring back a deleted item',
        'GET /items/{item}/stock-movements' => 'List the stock history of an item',
        'GET /customers/{customer}/ledger' => 'Show the account of a customer (udhar)',
        'GET /suppliers/{supplier}/ledger' => 'Show the account of a supplier',
        'GET /notifications' => 'List what needs attention (low stock, credit, VAT dates)',
        'GET /activity' => 'List recent actions of every user',
        'GET /cash-book' => 'Show money in and out with a running balance',
        'POST /sales/{sale}/cancel' => 'Cancel a sale and put the goods back',
        'POST /sales/{sale}/returns' => 'Return some goods of a sale',
        'POST /stock-adjustments' => 'Add or remove stock with a reason',
        'POST /stock-counts' => 'Save a stock count and fix the differences',
        'GET /reports/summary' => 'Sales, profit, stock value and credit for a date range',
        'GET /reports/daily' => 'Sales per day and per hour',
        'GET /reports/items' => 'Best and slowest selling items',
        'GET /reports/staff' => 'Sales per staff member',
        'GET /reports/credit-age' => 'Customer credit by how old it is',
        'GET /vat/preview' => 'Work out one VAT period without saving',
        'GET /vat/filings' => 'List saved VAT filings',
        'POST /vat/filings' => 'Save a VAT filing',
        'GET /vat/filings/{vatFiling}' => 'Show a VAT filing',
        'PATCH /vat/filings/{vatFiling}' => 'Update a VAT filing (paid, reference)',
    ];

    /** Bodies that the controller validates by hand, not in a form request. */
    private const BODIES = [
        'POST /items/{item}/photo' => [
            'type' => 'object',
            'required' => ['photo'],
            'properties' => ['photo' => ['type' => 'string', 'format' => 'binary', 'description' => 'jpg, jpeg, png or webp, at most 2 MB.']],
        ],
    ];

    private const TAGS = [
        'login' => 'Account', 'logout' => 'Account', 'logout-all' => 'Account', 'me' => 'Account',
        'forgot-password' => 'Account', 'reset-password' => 'Account',
        'cash-book' => 'Money', 'payments' => 'Money', 'expenses' => 'Money',
        'vat' => 'VAT', 'stock-adjustments' => 'Stock', 'stock-counts' => 'Stock',
    ];

    public function handle(): int
    {
        $json = json_encode($this->document(), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)."\n";
        $path = $this->option('path') ?: base_path('../docs/openapi.json');

        if ($this->option('check')) {
            if (! is_file($path) || file_get_contents($path) !== $json) {
                $this->error("{$path} is out of date. Run: php artisan pasal:openapi");

                return self::FAILURE;
            }
            $this->info('docs/openapi.json is up to date.');

            return self::SUCCESS;
        }

        file_put_contents($path, $json);
        $this->info("Wrote {$path}");

        return self::SUCCESS;
    }

    /** @return array<string, mixed> */
    public function document(): array
    {
        $paths = [];
        foreach (Router::getRoutes()->getRoutes() as $route) {
            if (! str_starts_with($route->uri(), self::PREFIX)) {
                continue;
            }
            $path = substr($route->uri(), strlen(self::PREFIX));
            $methods = array_diff($route->methods(), ['HEAD']);
            if (in_array('PUT', $methods, true)) {
                $methods = array_diff($methods, ['PATCH']); // Laravel registers both for a resource. Document PUT once.
            }
            foreach ($methods as $method) {
                $paths[$path][strtolower($method)] = $this->operation($route, $method, $path);
            }
        }
        ksort($paths);
        foreach ($paths as &$operations) {
            uksort($operations, fn ($a, $b) => array_search($a, ['get', 'post', 'put', 'patch', 'delete']) <=> array_search($b, ['get', 'post', 'put', 'patch', 'delete']));
        }

        return [
            'openapi' => '3.1.0',
            'info' => [
                'title' => 'PASAL API',
                'version' => '1.0.0',
                'description' => 'Billing, stock, credit (udhar) and VAT for a small shop in Nepal. Money is whole paisa. Days are Nepal days (UTC+5:45). Response bodies are only outlined here; see docs/api-reference.md for every field.',
                'license' => ['name' => 'AGPL-3.0-only', 'identifier' => 'AGPL-3.0-only'],
            ],
            'servers' => [['url' => 'http://localhost:8000/api/v1', 'description' => 'Local development']],
            'paths' => $paths,
            'components' => [
                'securitySchemes' => ['bearerAuth' => ['type' => 'http', 'scheme' => 'bearer', 'description' => 'Token from POST /login.']],
                'schemas' => [
                    'Error' => [
                        'type' => 'object',
                        'required' => ['message'],
                        'properties' => [
                            'message' => ['type' => 'string'],
                            'errors' => ['type' => 'object', 'description' => 'Only on 422. Field name to a list of messages.', 'additionalProperties' => ['type' => 'array', 'items' => ['type' => 'string']]],
                        ],
                    ],
                    'Record' => ['type' => 'object', 'properties' => ['data' => ['type' => 'object']]],
                    'Page' => [
                        'type' => 'object',
                        'properties' => [
                            'data' => ['type' => 'array', 'items' => ['type' => 'object']],
                            'links' => ['type' => 'object'],
                            'meta' => ['type' => 'object'],
                        ],
                    ],
                    'Message' => ['type' => 'object', 'properties' => ['message' => ['type' => 'string']]],
                ],
            ],
        ];
    }

    /** @return array<string, mixed> */
    private function operation(Route $route, string $method, string $path): array
    {
        $middleware = array_map(fn ($m) => is_string($m) ? $m : 'closure', Router::gatherRouteMiddleware($route)); // aliases resolved to class names
        $secured = (bool) preg_grep('/Authenticate:sanctum/', $middleware);
        $ownerOnly = (bool) preg_grep('/EnsureOwner/', $middleware);
        $action = explode('@', $route->getActionName());
        $verb = $action[1] ?? '';
        $segments = explode('/', trim($path, '/'));

        $op = [
            'operationId' => Str::camel(str_replace(['{', '}'], '', $method.'-'.implode('-', $segments))),
            'summary' => $this->summary($method, $path, $verb, $segments),
            'tags' => [self::TAGS[$segments[0]] ?? Str::headline($segments[0])],
        ];
        if ($ownerOnly) {
            $op['description'] = 'Owner only. Staff get 403.';
            $op['x-owner-only'] = true;
        }
        $op['security'] = $secured ? [['bearerAuth' => []]] : [];

        $parameters = [];
        preg_match_all('/\{(\w+)\}/', $path, $found);
        foreach ($found[1] as $name) {
            $parameters[] = ['name' => $name, 'in' => 'path', 'required' => true, 'schema' => ['type' => 'integer']];
        }
        if ($method === 'GET' && $verb === 'index') {
            $parameters[] = ['name' => 'page', 'in' => 'query', 'required' => false, 'schema' => ['type' => 'integer', 'minimum' => 1], 'description' => 'Lists are paged. Default 20 per page, max 50.'];
        }
        if ($method === 'POST' && $secured) {
            $parameters[] = ['name' => 'Idempotency-Key', 'in' => 'header', 'required' => false, 'schema' => ['type' => 'string', 'pattern' => '^[A-Za-z0-9._:-]{8,100}$'], 'description' => 'Send the same key on a retry so the action is saved once.'];
        }

        $schema = self::BODIES["{$method} {$path}"] ?? $this->requestSchema($route, $method, $action[0] ?? '', $verb);
        if ($schema !== null && $method === 'GET') {
            foreach ($schema['properties'] ?? [] as $name => $prop) {
                $parameters[] = ['name' => $name, 'in' => 'query', 'required' => in_array($name, $schema['required'] ?? [], true), 'schema' => $prop];
            }
        } elseif ($schema !== null) {
            $binary = str_contains(json_encode($schema), '"format":"binary"');
            $op['requestBody'] = ['required' => ! empty($schema['required']), 'content' => [$binary ? 'multipart/form-data' : 'application/json' => ['schema' => $schema]]];
        }
        if ($parameters) {
            $op['parameters'] = $parameters;
        }

        $op['responses'] = $this->responses($method, $verb, $secured, $ownerOnly, $schema !== null || str_contains($path, 'login'));

        return $op;
    }

    /** @param array<int, string> $segments */
    private function summary(string $method, string $path, string $verb, array $segments): string
    {
        if (isset(self::SUMMARIES["{$method} {$path}"])) {
            return self::SUMMARIES["{$method} {$path}"];
        }
        $noun = Str::lower(Str::headline(Str::singular(str_replace('-', ' ', $segments[0]))));
        $plural = Str::plural($noun);

        return match ($verb) {
            'index' => "List {$plural}",
            'show' => "Show one {$noun}",
            'store' => "Create a {$noun}",
            'update' => "Update a {$noun}",
            'destroy' => "Delete a {$noun}",
            default => Str::headline($verb),
        };
    }

    /** @return array<string, mixed> */
    private function responses(string $method, string $verb, bool $secured, bool $ownerOnly, bool $hasInput): array
    {
        $error = ['application/json' => ['schema' => ['$ref' => '#/components/schemas/Error']]];
        $page = ['$ref' => '#/components/schemas/Page'];
        $record = ['$ref' => '#/components/schemas/Record'];
        $message = ['$ref' => '#/components/schemas/Message'];

        $ok = match (true) {
            $method === 'GET' && $verb === 'index' => ['200', 'The list', $page],
            $method === 'GET' && $verb === 'show' => ['200', 'The record', $record],
            $method === 'POST' && $verb === 'store' => ['201', 'Created', $record],
            in_array($method, ['PUT', 'PATCH'], true) && in_array($verb, ['update'], true) => ['200', 'The updated record', $record],
            $method === 'DELETE' && $verb === 'destroy' => ['200', 'Deleted', $message],
            default => ['200', 'Done', ['type' => 'object']],
        };

        $responses = [$ok[0] => ['description' => $ok[1], 'content' => ['application/json' => ['schema' => $ok[2]]]]];
        if ($secured) {
            $responses['401'] = ['description' => 'No token, bad token, expired or revoked token', 'content' => $error];
        }
        if ($ownerOnly) {
            $responses['403'] = ['description' => 'Only the owner can do this', 'content' => $error];
        }
        if ($verb === 'show' || $verb === 'update' || $verb === 'destroy' || $verb === 'restore') {
            $responses['404'] = ['description' => 'Record not found, or it belongs to another shop', 'content' => $error];
        }
        if ($hasInput || $method !== 'GET') {
            $responses['422'] = ['description' => 'Bad input, or a business rule failed. Read `errors`', 'content' => $error];
        }
        $responses['429'] = ['description' => 'Too many requests. `Retry-After` says how many seconds to wait', 'content' => $error];
        ksort($responses);

        return $responses;
    }

    /** @return array<string, mixed>|null JSON schema of the validated input, or null when there is none to read */
    private function requestSchema(Route $route, string $method, string $controller, string $verb): ?array
    {
        $class = $this->formRequestOf($controller, $verb);
        if ($class === null) {
            return null;
        }
        $rules = $this->rulesOf($class, $route, $method);
        if ($rules === null) {
            return null;
        }

        $schema = ['type' => 'object'];
        foreach ($rules as $key => $rule) {
            $field = $this->field((array) $rule);
            if ($field === null) {
                continue; // prohibited for this caller
            }
            $this->place($schema, explode('.', (string) $key), $field[0], $field[1]);
        }

        return $schema;
    }

    private function formRequestOf(string $controller, string $verb): ?string
    {
        if (! class_exists($controller) || ! method_exists($controller, $verb)) {
            return null;
        }
        foreach ((new ReflectionMethod($controller, $verb))->getParameters() as $parameter) {
            $type = $parameter->getType();
            if ($type instanceof ReflectionNamedType && is_subclass_of($type->getName(), FormRequest::class)) {
                return $type->getName();
            }
        }

        return null;
    }

    /** @return array<string, mixed>|null */
    private function rulesOf(string $class, Route $route, string $method): ?array
    {
        $previous = Auth::user();
        try {
            // The rules read the caller (owner or staff) and the route. Document what an owner can send.
            $owner = (new User)->forceFill(['role' => 'owner', 'business_id' => 1]);
            Auth::setUser($owner);
            // A request to the same address with every {parameter} set to 1, so $this->route('item') works.
            $bound = clone $route;
            $address = '/'.preg_replace('/\{\w+\??\}/', '1', $route->uri());
            $request = $class::createFrom(Request::create($address, $method));
            $bound->bind($request);
            $request->setUserResolver(fn () => $owner);
            $request->setRouteResolver(fn () => $bound);

            return $request->rules();
        } catch (Throwable) {
            return null;
        } finally {
            if ($previous) {
                Auth::setUser($previous);
            } else {
                Auth::forgetGuards();
            }
        }
    }

    /**
     * One validation rule list to a JSON schema and a required flag. Null means the field is prohibited.
     *
     * @param  array<int, mixed>  $rules
     * @return array{0: array<string, mixed>, 1: bool}|null
     */
    private function field(array $rules): ?array
    {
        $names = [];
        foreach ($rules as $rule) {
            if (is_string($rule) || $rule instanceof Stringable) {
                $names[] = (string) $rule;
            } elseif (is_object($rule)) {
                $names[] = 'string'; // for example the password rule object
            }
        }
        if (in_array('prohibited', $names, true)) {
            return null;
        }

        $type = 'string';
        $schema = [];
        foreach ($names as $name) {
            [$rule, $arg] = array_pad(explode(':', $name, 2), 2, null);
            switch ($rule) {
                case 'integer': $type = 'integer';
                    break;
                case 'numeric': $type = 'number';
                    break;
                case 'boolean': $type = 'boolean';
                    break;
                case 'array': $type = 'array';
                    break;
                case 'email': $schema['format'] = 'email';
                    break;
                case 'file': case 'image': $schema['format'] = 'binary';
                    break;
                case 'date': $schema['description'] = 'Any date string, for example 2026-04-01 or 2026-04-01 10:30:00.';
                    break;
                case 'in': $schema['enum'] = array_map(fn ($v) => trim($v, '"'), explode(',', (string) $arg));
                    break;
            }
        }
        foreach ($names as $name) {
            [$rule, $arg] = array_pad(explode(':', $name, 2), 2, null);
            if (($rule === 'min' || $rule === 'max') && is_numeric($arg)) {
                $keyword = match ($type) {
                    'string' => $rule === 'min' ? 'minLength' : 'maxLength',
                    'array' => $rule === 'min' ? 'minItems' : 'maxItems',
                    default => $rule === 'min' ? 'minimum' : 'maximum',
                };
                $schema[$keyword] = $arg + 0;
            }
        }
        $schema = ['type' => in_array('nullable', $names, true) ? [$type, 'null'] : $type] + $schema;

        return [$schema, in_array('required', $names, true)];
    }

    /**
     * Puts a field into the schema tree. `items.*.item_id` becomes an array of objects with an `item_id`.
     *
     * @param  array<string, mixed>  $node
     * @param  array<int, string>  $path
     * @param  array<string, mixed>  $field
     */
    private function place(array &$node, array $path, array $field, bool $required): void
    {
        if ($path === []) {
            $node = array_merge($node, $field);

            return;
        }
        $head = array_shift($path);
        if ($head === '*') {
            $node['type'] = 'array';
            $node['items'] ??= ['type' => 'object'];
            $this->place($node['items'], $path, $field, $required);

            return;
        }
        $node['properties'][$head] ??= [];
        $this->place($node['properties'][$head], $path, $field, $required);
        if ($required && $path === []) {
            $node['required'][] = $head;
        }
    }
}
