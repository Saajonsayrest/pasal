import 'dart:ui' show Size;

import 'package:pasal_mobile/core/models/models.dart';

/// The test font (Ahem) is much wider than Inter, so the screen tests use a wider canvas than a phone.
const testCanvas = Size(800, 1400);

/// A customer who owes Rs 15,000 on two open bills, with a Rs 10,000 credit limit (over by Rs 5,000).
/// Bill S-0031 (Rs 11,300) got Rs 5,000 in cash on 5 Oct, so Rs 6,300 is still open.
Json ledgerJson({int? creditLimit = 1000000}) => {
      'customer': {
        'id': 4,
        'name': 'Hari Thapa',
        'phone': '9800000004',
        'address': null,
        'pan': null,
        'credit_limit': creditLimit,
      },
      'total_sales': 2000000,
      'total_paid': 500000,
      'owes': 1500000,
      'credit_limit': creditLimit,
      'sales': [
        {
          'id': 31,
          'bill_no': 'S-0031',
          'sold_at': '2026-10-01T04:00:00+00:00',
          'total': 1130000,
          'returned_total': 0,
          'paid': 500000,
          'balance': 630000,
          'cancelled_at': null,
        },
        {
          'id': 32,
          'bill_no': 'S-0032',
          'sold_at': '2026-10-20T04:00:00+00:00',
          'total': 870000,
          'returned_total': 0,
          'paid': 0,
          'balance': 870000,
          'cancelled_at': null,
        },
      ],
      'payments': [
        {
          'id': 9,
          'direction': 'in',
          'sale_id': 31,
          'purchase_id': null,
          'amount': 500000,
          'method': 'cash',
          'paid_at': '2026-10-05T04:00:00+00:00',
          'party': 'Hari Thapa',
        },
      ],
    };

/// One customer as the list and detail answers send it.
Json customerJson({int id = 4, String name = 'Hari Thapa', int? owes = 1500000, int? creditLimit}) => {
      'id': id,
      'name': name,
      'phone': '98000000$id',
      'address': null,
      'pan': null,
      'credit_limit': creditLimit,
      'owes': owes,
      'last_sale_at': null,
      'oldest_unpaid_at': null,
    };
