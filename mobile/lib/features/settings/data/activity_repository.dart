import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// One page of the activity log. A null [userId] means everyone.
typedef ActivityQuery = ({int? userId, int page});

const activityPerPage = 30;

/// Talks to /activity (owner only).
class ActivityRepository {
  ActivityRepository(this._api);

  final ApiClient _api;

  Future<Paged<ActivityEntry>> page(ActivityQuery q) => _api.page(
        '/activity',
        ActivityEntry.fromJson,
        query: {'per_page': activityPerPage, 'page': q.page, 'user_id': q.userId},
      );
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) => ActivityRepository(ref.watch(apiClientProvider)));

final activityProvider = FutureProvider.autoDispose.family<Paged<ActivityEntry>, ActivityQuery>(
  (ref, query) => ref.watch(activityRepositoryProvider).page(query),
);
