import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final bool enableJs;
  final String data;
  const WebViewPage(
      {super.key,
      required this.url,
      required this.title,
      this.data = "",
      this.enableJs = true});

  @override
  WebViewPageState createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  late WebViewController controller = WebViewController();

// 读取 Assets 中的 HTML 文件并加载
  Future<void> loadAssetsHtml(String? data) async {
    if (data!.isEmpty) {
      try {
        // 1. 读取 HTML 文件内容（路径对应 Assets 目录）
        final htmlContent = await rootBundle.loadString('assets/html/log.html');

        // 2. 加载 HTML 字符串（关键：设置 baseUrl 为 Assets 路径，支持引用同目录资源）
        await controller.loadHtmlString(
          htmlContent,
          // baseUrl 必须设置，否则 HTML 中引用的 CSS/JS/图片会找不到
          baseUrl: 'asset:///assets/html/',
        );
      } catch (e) {
        print('加载 Assets HTML 失败：$e');
        // 加载失败提示
        await controller.loadHtmlString('<body><h1>加载失败</h1><p>$e</p></body>');
      }
    } else {
      await controller.loadHtmlString(data);
    }
  }

  @override
  void initState() {
    super.initState();

    controller.setJavaScriptMode(widget.enableJs
        ? JavaScriptMode.unrestricted
        : JavaScriptMode.disabled);
    if (widget.data != "") {
      loadAssetsHtml(widget.data);
    } else {
      if (widget.url.startsWith('http://') ||
          widget.url.startsWith('https://')) {
        controller.loadRequest(Uri.parse(widget.url));
      } else {
        loadAssetsHtml(widget.data);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: widget.title == 'None' ? null : Text(widget.title),
      ),
      body: WebViewWidget(
        controller: controller,
      ),
    );
  }
}
