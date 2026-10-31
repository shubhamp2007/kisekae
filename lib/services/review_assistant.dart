import 'package:dio/dio.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/review_summary.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class ReviewAssistant extends BaseRepository {
  static const int maxHistoryMessages = 10;

  final Dio _dio;

  ReviewAssistant([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<ReviewSummary?> getSummary(int productId) async {
    try {
      return await execute(() async {
        final response = await _dio.get(
          '/products/$productId/reviews/summary/',
        );

        final body = Map<String, dynamic>.from(response.data as Map);
        final data = Map<String, dynamic>.from(body['data'] as Map);

        return ReviewSummary.fromJson(data);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.code == 'SUMMARY_NOT_AVAILABLE') return null;
      rethrow;
    }
  }

  Future<ReviewChatReply> askQuestion(
    int productId,
    String question, {
    List<ReviewChatMessage> history = const [],
  }) async {
    final recent = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;

    return execute(() async {
      final response = await _dio.post(
        '/products/$productId/reviews/chat/',
        data: {
          'question': question.trim(),
          'history': recent.map((message) => message.toJson()).toList(),
        },
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return ReviewChatReply.fromJson(data);
    });
  }
}
