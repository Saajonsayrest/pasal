<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BusinessController;
use App\Http\Controllers\Api\V1\CashBookController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\ExpenseController;
use App\Http\Controllers\Api\V1\ItemController;
use App\Http\Controllers\Api\V1\LedgerController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PurchaseController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\SaleController;
use App\Http\Controllers\Api\V1\SaleReturnController;
use App\Http\Controllers\Api\V1\StockAdjustmentController;
use App\Http\Controllers\Api\V1\StockCountController;
use App\Http\Controllers\Api\V1\StockMovementController;
use App\Http\Controllers\Api\V1\SupplierController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\VatController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');

    Route::middleware('throttle:password-reset')->group(function () {
        Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
        Route::post('/reset-password', [AuthController::class, 'resetPassword']);
    });

    // A POST with an Idempotency-Key header is saved once, even if the phone sends it twice.
    Route::middleware(['auth:sanctum', 'throttle:120,1', 'idempotent'])->group(function () {
        // Everyone in a business (owner and staff): the counter work.
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::post('/logout-all', [AuthController::class, 'logoutAll']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/me/password', [AuthController::class, 'changePassword']);
        Route::get('/business', [BusinessController::class, 'show']);

        Route::get('/categories', [CategoryController::class, 'index']);
        Route::get('/categories/{category}', [CategoryController::class, 'show']);
        Route::get('/items', [ItemController::class, 'index']);
        Route::get('/items/suggest', [ItemController::class, 'suggest']);
        Route::get('/items/{item}', [ItemController::class, 'show']);

        Route::apiResource('customers', CustomerController::class);
        Route::get('/customers/{customer}/ledger', [LedgerController::class, 'customer']);

        Route::apiResource('sales', SaleController::class)->only(['index', 'store', 'show']);
        Route::post('/payments', [PaymentController::class, 'store']);

        // Owner only: stock, buying, money, reports, tax, people and settings.
        Route::middleware('owner')->group(function () {
            Route::patch('/business', [BusinessController::class, 'update']);

            Route::apiResource('users', UserController::class)->only(['index', 'store', 'update', 'destroy']);

            Route::apiResource('categories', CategoryController::class)->only(['store', 'update', 'destroy']);
            Route::apiResource('items', ItemController::class)->only(['store', 'update', 'destroy']);
            Route::post('/items/{item}/restore', [ItemController::class, 'restore']);
            Route::post('/stock-adjustments', [StockAdjustmentController::class, 'store']);
            Route::post('/stock-counts', [StockCountController::class, 'store']);
            Route::get('/items/{item}/stock-movements', [StockMovementController::class, 'index']);

            Route::post('/sales/{sale}/returns', [SaleReturnController::class, 'store']);
            Route::post('/sales/{sale}/cancel', [SaleReturnController::class, 'cancel']);

            Route::get('/payments', [PaymentController::class, 'index']);
            Route::get('/cash-book', [CashBookController::class, 'index']);

            Route::apiResource('suppliers', SupplierController::class);
            Route::get('/suppliers/{supplier}/ledger', [LedgerController::class, 'supplier']);
            Route::apiResource('purchases', PurchaseController::class)->only(['index', 'store', 'show']);
            Route::apiResource('expenses', ExpenseController::class)->only(['index', 'store']);

            Route::get('/reports/summary', [ReportController::class, 'summary']);

            Route::get('/vat/preview', [VatController::class, 'preview']);
            Route::get('/vat/filings', [VatController::class, 'index']);
            Route::post('/vat/filings', [VatController::class, 'store']);
            Route::get('/vat/filings/{vatFiling}', [VatController::class, 'show']);
            Route::patch('/vat/filings/{vatFiling}', [VatController::class, 'update']);
        });
    });
});
