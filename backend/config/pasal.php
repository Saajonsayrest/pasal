<?php

return [
    // VAT rate in percent given to a NEW business. Each business keeps its own rate in the
    // businesses table. The Finance Act sets the real rate each year, so check it with IRD.
    'default_vat_rate' => (float) env('PASAL_VAT_RATE', 13),

    // Return is due this many days after the Nepali month ends (VAT Act 2052, section 18).
    'vat_due_days' => 25,
];
