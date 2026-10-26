<?php

namespace App\Console\Commands;

use App\Models\Business;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

use function Laravel\Prompts\password;
use function Laravel\Prompts\text;

class AddBusiness extends Command
{
    protected $signature = 'pasal:add-business';

    protected $description = 'Create a new business and its owner login. Sign-up is invite-only, so this is how a customer starts.';

    public function handle(): int
    {
        $businessName = text('Business name', required: true);
        $pan = text('PAN number (press Enter to skip)');
        $ownerName = text('Owner name', required: true);
        $email = text('Owner email', required: true, validate: fn (string $v) => filter_var($v, FILTER_VALIDATE_EMAIL) ? null : 'Not a valid email.');
        $pass = password('Owner password (min 10 characters)', required: true, validate: fn (string $v) => strlen($v) >= 10 ? null : 'Too short.');

        if (User::where('email', $email)->exists()) {
            $this->error('That email already has a login.');

            return self::FAILURE;
        }

        DB::transaction(function () use ($businessName, $pan, $ownerName, $email, $pass) {
            $business = Business::create([
                'name' => $businessName,
                'pan' => $pan ?: null,
                'vat_rate' => config('pasal.default_vat_rate'),
            ]);

            $owner = new User(['name' => $ownerName, 'email' => $email, 'password' => $pass]);
            $owner->business_id = $business->id;
            $owner->role = 'owner';
            $owner->save();
        });

        $this->info("Business '{$businessName}' created. The owner can log in as {$email}.");

        return self::SUCCESS;
    }
}
