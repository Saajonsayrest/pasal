<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\VatFilingRequest;
use App\Http\Requests\Api\V1\VatFilingUpdateRequest;
use App\Http\Requests\Api\V1\VatPreviewRequest;
use App\Http\Resources\Api\V1\VatFilingResource;
use App\Models\VatFiling;
use App\Services\VatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class VatController extends Controller
{
    private const NUMBER_FIELDS = ['sales_taxable', 'sales_exempt', 'output_vat', 'purchases_taxable', 'input_vat', 'carry_in', 'payable', 'carry_out'];

    /** Work out a period without saving anything. */
    public function preview(VatPreviewRequest $request, VatService $vat): JsonResponse
    {
        $data = $request->validated();

        return response()->json($vat->preview(Carbon::parse($data['from']), Carbon::parse($data['to']), (int) ($data['opening_carry'] ?? 0)));
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        return VatFilingResource::collection(
            VatFiling::orderByDesc('period_to')->paginate(min((int) $request->query('per_page', 20), 50))
        );
    }

    public function show(VatFiling $vatFiling): VatFilingResource
    {
        return new VatFilingResource($vatFiling);
    }

    /** Save a period. Computed from our records, or typed in by hand for an old return. */
    public function store(VatFilingRequest $request, VatService $vat): JsonResponse
    {
        $data = $request->validated();

        $overlap = VatFiling::where('period_from', '<=', $data['to'])->where('period_to', '>=', $data['from'])->exists();
        if ($overlap) {
            throw ValidationException::withMessages(['from' => ['These dates overlap a period you already saved.']]);
        }

        if (! empty($data['manual'])) {
            $numbers = collect($data)->only(self::NUMBER_FIELDS)->all();
            $source = 'manual';
        } else {
            $calc = $vat->preview(Carbon::parse($data['from']), Carbon::parse($data['to']), (int) ($data['opening_carry'] ?? 0));
            $numbers = collect($calc)->only(self::NUMBER_FIELDS)->all();
            $source = 'computed';
        }

        $filing = VatFiling::create([
            ...$numbers,
            'period' => $data['period'],
            'period_from' => $data['from'],
            'period_to' => $data['to'],
            'source' => $source,
            'filed_on' => $data['filed_on'] ?? null,
            'paid_amount' => $data['paid_amount'] ?? 0,
            'paid_on' => $data['paid_on'] ?? null,
            'receipt_no' => $data['receipt_no'] ?? null,
            'note' => $data['note'] ?? null,
            'user_id' => $request->user()->id,
        ]);

        return (new VatFilingResource($filing))->response()->setStatusCode(201);
    }

    public function update(VatFilingUpdateRequest $request, VatFiling $vatFiling): VatFilingResource
    {
        $vatFiling->update($request->validated());

        return new VatFilingResource($vatFiling);
    }
}
