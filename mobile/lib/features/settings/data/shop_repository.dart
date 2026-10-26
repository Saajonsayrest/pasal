import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bill footer is saved on this phone only (SharedPreferences). The bill screen reads the same key.
const billFooterKey = 'pasal_bill_footer';
const defaultBillFooter = 'Thank you. Please visit again.';

/// Talks to /business (the shop details and VAT rate).
class ShopRepository {
  ShopRepository(this._api);

  final ApiClient _api;

  Future<Business> get() async => Business.fromJson((await _api.get('/business'))['data'] as Json);

  /// Blank optional fields are sent as null, so the server clears them.
  Future<Business> update({
    required String name,
    required double vatRate,
    String? pan,
    String? phone,
    String? address,
  }) async {
    final res = await _api.patch(
      '/business',
      body: {'name': name, 'pan': pan, 'phone': phone, 'address': address, 'vat_rate': vatRate},
    );
    return Business.fromJson(res['data'] as Json);
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) => ShopRepository(ref.watch(apiClientProvider)));

final shopProvider = FutureProvider.autoDispose<Business>((ref) => ref.watch(shopRepositoryProvider).get());

String readBillFooter(SharedPreferences prefs) => prefs.getString(billFooterKey) ?? defaultBillFooter;

Future<void> writeBillFooter(SharedPreferences prefs, String text) {
  final trimmed = text.trim();
  return prefs.setString(billFooterKey, trimmed.isEmpty ? defaultBillFooter : trimmed);
}
