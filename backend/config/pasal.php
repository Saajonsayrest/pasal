<?php

return [
    // VAT rate in percent given to a NEW business. Each business keeps its own rate in the
    // businesses table. The Finance Act sets the real rate each year, so check it with IRD.
    'default_vat_rate' => (float) env('PASAL_VAT_RATE', 13),

    // Most discount (percent of the bill) a staff user can give. The owner has no limit.
    'staff_max_discount_percent' => (int) env('PASAL_STAFF_MAX_DISCOUNT_PERCENT', 10),

    // Where the password reset email sends the person. The app (deep link) or a web page that
    // reads ?token= and ?email= and calls POST /api/v1/reset-password.
    'password_reset_url' => env('PASAL_PASSWORD_RESET_URL', 'pasal://reset-password'),

    // Return is due this many days after the Nepali month ends (VAT Act 2052, section 18).
    'vat_due_days' => 25,
];
