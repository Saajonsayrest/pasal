import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// The four first-run steps. A step is done when the shop has the data for it.
class SetupChecklist {
  const SetupChecklist({required this.shop, required this.itemCount, required this.customerCount, required this.userCount});

  final Business shop;
  final int itemCount;
  final int customerCount;

  /// Every user of the business, the owner included.
  final int userCount;

  bool get shopDone => [shop.phone, shop.address, shop.pan].every((v) => (v ?? '').trim().isNotEmpty);
  bool get itemDone => itemCount > 0;
  bool get customerDone => customerCount > 0;
  bool get staffDone => userCount > 1;

  int get doneCount => [shopDone, itemDone, customerDone, staffDone].where((done) => done).length;
}

/// Password reset, password change and the first-run checklist. Talks to /forgot-password,
/// /reset-password, /me/password, /business, /items, /customers and /users.
class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<void> forgotPassword(String email) async {
    await _api.post('/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword({required String email, required String token, required String password}) async {
    await _api.post('/reset-password', body: {'email': email, 'token': token, 'password': password});
  }

  Future<void> changePassword({required String currentPassword, required String password}) async {
    await _api.post('/me/password', body: {'current_password': currentPassword, 'password': password});
  }

  Future<SetupChecklist> setupChecklist() async {
    final answers = await Future.wait<Object>([
      _api.get('/business').then<Object>((json) => Business.fromJson(json['data'] as Json)),
      _api.page('/items', Item.fromJson, query: {'per_page': 1}).then<Object>((page) => page.meta.total),
      _api.page('/customers', Customer.fromJson, query: {'per_page': 1}).then<Object>((page) => page.meta.total),
      _api.page('/users', AppUser.fromJson, query: {'per_page': 1}).then<Object>((page) => page.meta.total),
    ]);
    return SetupChecklist(
      shop: answers[0] as Business,
      itemCount: answers[1] as int,
      customerCount: answers[2] as int,
      userCount: answers[3] as int,
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(apiClientProvider)));

final setupChecklistProvider = FutureProvider.autoDispose<SetupChecklist>((ref) => ref.watch(accountRepositoryProvider).setupChecklist());
