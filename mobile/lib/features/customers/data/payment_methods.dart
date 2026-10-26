/// How a customer paid. Same keys and names as the website (web/src/routes/E3TakePayment.svelte).
class PaymentMethod {
  const PaymentMethod(this.key, this.en, this.ne);

  final String key;
  final String en;
  final String ne;
}

const paymentMethods = <PaymentMethod>[
  PaymentMethod('cash', 'Cash', 'नगद'),
  PaymentMethod('qr', 'QR', 'QR'),
  PaymentMethod('bank', 'Bank', 'बैंक'),
  PaymentMethod('esewa', 'eSewa', 'eSewa'),
  PaymentMethod('khalti', 'Khalti', 'Khalti'),
];

/// The method's name for the screen language. An unknown key is shown as it is.
String paymentMethodName(String key, {required bool ne}) {
  for (final m in paymentMethods) {
    if (m.key == key) return ne ? m.ne : m.en;
  }
  return key;
}
