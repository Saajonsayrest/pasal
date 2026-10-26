import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// Talks to /users (owner only). A person in the list is an [AppUser] (no business inside).
class StaffRepository {
  StaffRepository(this._api);

  final ApiClient _api;

  Future<List<AppUser>> list() => _api.all('/users', AppUser.fromJson);

  Future<AppUser> add({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await _api.post('/users', body: {'name': name, 'email': email, 'password': password, 'role': role});
    return AppUser.fromJson(res['data'] as Json);
  }

  /// Send only the fields that changed. A changed role or password signs that person out everywhere.
  Future<void> update(int id, Map<String, Object?> changes) async {
    await _api.patch('/users/$id', body: changes);
  }

  Future<void> remove(int id) async {
    await _api.delete('/users/$id');
  }
}

final staffRepositoryProvider = Provider<StaffRepository>((ref) => StaffRepository(ref.watch(apiClientProvider)));

final staffProvider = FutureProvider.autoDispose<List<AppUser>>((ref) => ref.watch(staffRepositoryProvider).list());
