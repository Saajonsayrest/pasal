<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\BusinessRequest;
use App\Http\Resources\Api\V1\BusinessResource;
use Illuminate\Http\Request;

class BusinessController extends Controller
{
    public function show(Request $request): BusinessResource
    {
        return new BusinessResource($request->user()->business);
    }

    public function update(BusinessRequest $request): BusinessResource
    {
        $business = $request->user()->business;
        $business->update($request->validated());

        return new BusinessResource($business);
    }
}
