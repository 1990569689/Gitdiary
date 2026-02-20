import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ChatApi {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  // = "https://api.siliconflow.cn/v1/chat/completions"

  ChatApi(this._baseUrl, this._apiKey) : _dio = Dio() {
      
    _dio.options.headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $_apiKey",
      "Connection": "keep-alive"
    };
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  // 流式问答请求，返回 Stream<String>
  Stream<String> streamChat(String prompt, String model) async* {
    try {
      final response = await _dio.post(
        _baseUrl + "/chat/completions",
        data: {
          "model": model,
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "stream": true,
          "temperature": 0.7,
          "max_tokens": 2048
        },
        options: Options(responseType: ResponseType.stream),
      );

      // 核心修复：适配 Uint8List 类型的 Stream
      final Stream<Uint8List> uint8Stream = response.data.stream;
      // 1. 自定义 Transformer：将 Uint8List 转为 List<int>
      final uint8ToListTransformer =
          StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleData: (Uint8List data, EventSink<List<int>> sink) {
          // Uint8List 转 List<int>（本质是同一类字节数据，只是类型标注不同）
          sink.add(data.toList());
        },
      );
      if (response.statusCode == 200) {
        // 2. 先转 List<int>，再解码为字符串，最后按行分割
        final stream = uint8Stream
            .transform(uint8ToListTransformer) // 关键：Uint8List → List<int>
            .transform(utf8.decoder) // List<int> → String
            .transform(const LineSplitter()); // 按行分割

        await for (final line in stream) {
          if (line.isEmpty || !line.startsWith("data: ")) continue;

          final data = line.replaceFirst("data: ", "").trim();
          if (data == "[DONE]") break;

          try {
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            final choices = jsonData["choices"] as List? ?? [];

            if (choices.isNotEmpty) {
              final delta =
                  choices.first["delta"] as Map<String, dynamic>? ?? {};
              final content = delta["content"] as String? ?? "";
              if (content.isNotEmpty) yield content;
            }
          } on FormatException catch (e) {
            yield "JSON解析错误: ${e.message}";
          }
        }
      } else {
        yield "错误码: ${response.statusCode}, 响应内容: ${response.data}";
        //     on DioException catch (e) {
        //   yield "请求异常: ${e.message ?? '未知Dio错误'}";
        //   if (e.response != null) {
        //     yield "错误码: ${e.response?.statusCode}, 响应内容: ${e.response?.data}";
        //   }
        // }
      }
    } catch (e) {
      yield "未知错误: $e";
    }
  }

  void dispose() {
    _dio.close();
  }
}
