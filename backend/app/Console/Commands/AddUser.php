<?php

namespace App\Console\Commands;

use App\Models\Business;
use App\Models\User;
use Illuminate\Console\Command;

use function Laravel\Prompts\password;
use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

class AddUser extends Command
{
    protected $signature = 'pasal:add-user';

    protected $description = 'Add a login to an existing business. Asks for the business, role, name, email and password.';

    public function handle(): int
    {
        $businesses = Business::orderBy('name')->pluck('name', 'id')->all();

        if ($businesses === []) {
            $this->error('No business yet. Run pasal:add-business first.');

            return self::FAILURE;
        }

        $businessId = select('Which business?', $businesses);
        $role = select('Role', ['owner' => 'Owner (sees and does everything)', 'staff' => 'Staff (counter work only)'], default: 'staff');
        $name = text('Name', required: true);
        $email = text('Email', required: true, validate: fn (string $v) => filter_var($v, FILTER_VALIDATE_EMAIL) ? null : 'Not a valid email.');
        $pass = password('Password (min 10 characters)', required: true, validate: fn (string $v) => strlen($v) >= 10 ? null : 'Too short.');

        if (User::where('email', $email)->exists()) {
            $this->error('That email already has a login.');

            return self::FAILURE;
        }

        $user = new User(['name' => $name, 'email' => $email, 'password' => $pass]);
        $user->business_id = (int) $businessId;
        $user->role = $role;
        $user->save();

        $this->info("User {$email} created as {$role}.");

        return self::SUCCESS;
    }
}
