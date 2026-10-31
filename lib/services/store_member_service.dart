import 'package:dio/dio.dart';
import 'package:kisekae/models/store_create.dart';
import 'package:kisekae/models/store_member.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class StoreMembers extends BaseRepository {
  final Dio _dio;

  StoreMembers([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<List<StoreMember>> getMembers(
    int storeId, {
    String? role,
    String? search,
    String ordering = 'created_at',
  }) async {
    return execute(() async {
      final response = await _dio.get(
        '/stores/$storeId/members/',
        queryParameters: {
          if (role != null) 'role': role,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'ordering': ordering,
        },
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = body['data'] as List<dynamic>? ?? [];

      return data
          .map(
            (item) =>
                StoreMember.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    });
  }

  Future<void> removeMember(int storeId, int memberId) async {
    return execute(() async {
      await _dio.delete('/stores/$storeId/members/$memberId/');
    });
  }

  Future<void> leaveStore(int storeId) async {
    return execute(() async {
      await _dio.post('/stores/$storeId/leave/');
    });
  }

  Future<Store> transferOwnership(int storeId, int memberId) async {
    return execute(() async {
      final response = await _dio.post(
        '/stores/$storeId/transfer-ownership/',
        data: FormData.fromMap({'member_id': memberId}),
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return Store.fromJson(data);
    });
  }
}
