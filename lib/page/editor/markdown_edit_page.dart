import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/chat.dart';
import 'package:editor/generators/custom_node.dart';
import 'package:editor/generators/latex.dart';
import 'package:editor/generators/video.dart';
import 'package:editor/main.dart';
import 'package:editor/page/ai/chat_page.dart';
import 'package:editor/page/backups/webdav.dart';
import 'package:editor/page/person/github_api.dart';
import 'package:editor/provider.dart';
import 'package:editor/theme.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:editor/widget/dialog_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:highlight/languages/markdown.dart';
import 'package:html/parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/widget/markdown.dart';
// import 'package:markdown_widget/widget/all.dart';
// import 'package:markdown_widget/widget/all.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:markdown/markdown.dart' as md; // 引入语法扩展
import 'package:highlight/highlight.dart' show highlight, Language;
import 'package:html2md/html2md.dart' as html2md;
import 'package:highlight/languages/all.dart'; // 导入所有语言的高亮规则（也可按需导入）
import 'package:html/dom.dart' as dom;
import 'dart:math' as math; // 处理反向选择的情况
import 'package:flutter/services.dart'; // TextSelection 依赖
// import 'package:dart/math.dart';
import 'package:path/path.dart' as path;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:markdown_widget/markdown_widget.dart';

// import 'package:markd/markdown.dart' as markd;
// import 'package:markd/src/ast.dart' as markd_ast;
class EditorPage extends StatefulWidget {
  final String filePath;
  final String? fileName;
  const EditorPage({
    super.key,
    required this.filePath,
    this.fileName,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  // 新增GitHub配置控制器
  late TextEditingController _githubRepoController = TextEditingController();
  late TextEditingController _githubBranchController = TextEditingController();
  late TextEditingController _controller = TextEditingController();
  // 仅监听文本变化，避免全Widget重建
  final ValueNotifier<int> _lengthNotifier = ValueNotifier(0);
  late FocusNode _focusNode;
  double loadProgress = 0.0;
  bool _isPreview = false; // 是否预览模式
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isEmpty = true;
  bool _isEdit = true;
  bool _isToolBarVisible = true;
  Map<String, dynamic> gitConfig = Utils.getGitConfig();
  final ImagePicker _imagePicker = ImagePicker(); // 初始化图片选择器
  Brightness isDark = Brightness.dark;
  final TocController controller = TocController();
  late String html = "";
  // bool get isMobile => PlatformDetector.isAllMobile;
  // 显示错误提示弹窗
  final Map<String, dynamic> config = Utils.getWriteConfig();
  //  'view_count': _prefs.getBool('write_view_count') ?? true,
  //     'link_color': _prefs.getString('write_link_color') ?? '',
  //     'quote_color': _prefs.getString('write_quote_color') ?? '',
  //     'code_font_color': _prefs.getString('write_code_font_color') ?? '',
  //     'code_bg_color': _prefs.getString('write_code_bg_color') ?? '',
  //     'font_size': _prefs.getInt('write_font_size') ?? 12,
  //     'image_quality': _prefs.getInt('write_image_quality') ?? 80,
  //     'auto_times': _prefs.getInt('write_auto_times') ?? 5,
  // 替换为你的硅基流动 API Key
  late final ChatApi _api = ChatApi(Utils.getAiConfig()['api'].toString(),
      Utils.getAiConfig()['token'].toString());
  bool _isSharing = false;
  bool _isWidgetReady = false;
  final ScrollController _scrollController = ScrollController();
  // 用于捕获RepaintBoundary的全局Key
  final GlobalKey _captureKey = GlobalKey();
  String _quoteTextColor = "";
  String _answer = "";
  String _linkColor = "";
  String _quoteColor = "";
  String _codeFontColor = "";
  String _codeBgColor = "";
  int _imageQuality = 80;
  int _autoTimes = 5;
  int _render = 0;
  bool _theme = false;
  //_render=0; _render=1可见可得
  double _fontSize = 12.0;
  bool _switchValue1 = true;
  FilterQuality _filterQuality = FilterQuality.high;
  Timer? _saveTimer; // 定时任务对象，用于后续取消
  InAppWebViewController? webController;
  // ''' +
  //       (Provider.of<ThemeNotifier>(context, listen: false).currentTheme ==
  //               ThemeType.light
  //           ? ''
  //           : '''
  // <style>
  // body {
  //   background-color: #$backgroundColor;
  //   color: #$textColor;
  // }
  // a {
  //   color: #$accentColor;
  // }
  // img {
  //   filter: grayscale(20%);
  // }
  // </style>
  // ''') +
  //       '''
  String staticPreviewDir =
      'file:///android_asset/flutter_assets/assets/preview';
  Future<void> preview(String html) async {
    String backgroundColor = ThemeUtil.getIsDark() ? "#000000" : "#ffffff";
    String textColor = ThemeUtil.getIsDark() ? "#ffffff" : "#000000";
    String tabColor = ThemeUtil.getIsDark() ? "#000000" : "#f8f8f8";
    String tabsColor = ThemeUtil.getIsDark() ? "#000000" : "#fafafa";
    String generatedPreview = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" >
	<link href="file:///android_asset/flutter_assets/assets/preview/prism.css" rel="stylesheet" />
  <link rel="stylesheet" href="file:///android_asset/flutter_assets/assets/preview/katex.min.css">
  <script defer src="file:///android_asset/flutter_assets/assets/preview/katex.min.js"></script>
  <script defer src="file:///android_asset/flutter_assets/assets/preview/mhchem.min.js"></script>
  <script src="file:///android_asset/flutter_assets/assets/preview/asciimath2tex.umd.js" ></script>
  <script defer src="file:///android_asset/flutter_assets/assets/preview/katex.auto-render.min.js"
        onload="const parser = new AsciiMathParser();renderMathInElement(document.body,
        {delimiters:
        [
          {left: '\$\$', right: '\$\$', display: true},
          {left: '\$', right: '\$', display: false},
        ],
        preProcess: (math)=>{
          return math.trim();
        }
        });
renderMathInElement(document.body,
        {delimiters:
        [
          {left: '&&', right: '&&', display: true},
          {left: '&', right: '&', display: false},
        ],
        preProcess: (math)=>{
          return parser.parse(math.trim());
        }
        });
"></script>
<style>

    .task-list-item {
      list-style: none; 
  
      font-size:0.8rem;
      line-height: 1.5;
    }
    .task-list-item input[type="checkbox"] {
      width: 0.9rem;       
      height: 0.9rem;      
      vertical-align: middle; 
      margin-right: 1em;
      cursor: pointer;  
    }
 html {
      line-height: 1.2;
      -webkit-text-size-adjust: 100%;
      height: 100%;
      overflow-x: hidden;
      font-size: calc(100vw / 375 * 16);
      -webkit-tap-highlight-color: rgba(0, 0, 0, 0);
      min-height: 100px;
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      word-wrap: break-word;
      background-color: ${backgroundColor};
      color:${textColor};
    }
    body {
      margin: 10px;
      padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
      box-sizing: border-box;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", Arial, sans-serif;
      background-color: ${backgroundColor};
      color:${textColor};
      -webkit-tap-highlight-color: rgba(0, 0, 0, 0.1);
    }
    main {
      display: block;
    }
    h1,
    h2,
    h3,
    h4,
    h5,
    h6 {
      margin: 0.8em 0 0.4em;
      font-weight: 600;
      line-height: 1.3;
    }
    h1 {
      margin-top: 0; 
      font-size: 1.6rem;
      border-bottom: 1px solid #eee;
      padding-bottom: 0.5em;
    }
    h2 {
      font-size: 1.4rem;
      border-bottom: 1px solid #eee;
      padding-bottom: 0.5em;
    }
    h3 {
      font-size: 1.2rem;
    }
    h4 {
      font-size: 1rem;
    }
    h5 {
      font-size: 0.9rem;
    }
    h6 {
      font-size: 0.8rem;
    }
    p {
      margin: 0.6em 0;
      line-height: 1.6;
      font-size:0.8rem;
      text-align: justify;
    }
    hr {
      box-sizing: content-box;
      height: 0;
      overflow: visible;
      border: none;
      border-top: 2px solid #eee;
      margin: 1.5rem 0;
    }
    a {
      background-color: transparent;
      color: #0066cc;
      font-size:0.8rem;
      text-decoration: none;
      word-break: break-all;
    }
    a:hover {
      text-decoration: underline;
    }
    abbr[title] {
      border-bottom: none;
      text-decoration: underline;
      text-decoration: underline dotted;
    }
    b,
    strong {
      font-weight: bolder;
      font-weight: 600;
    }
    code,
    kbd,
    samp {
      font-family: "SF Mono", Monaco, Consolas, monospace;
      font-size: 0.8rem;
      border-radius: 2px 2px 2px 2px;
      padding: 2px;
    }
    small {
      font-size: 80%;
    }
    sub,
    sup {
      font-size: 75%;
      line-height: 0;
      position: relative;
      vertical-align: baseline;
    }
    sub {
      bottom: -0.25em;
    }
    sup {
      top: -0.5em;
    }
    img {
      border-style: none;
      max-width: 100%;
      height: auto;
      width: auto;
      vertical-align: middle; 
      margin: 0.1rem;
      border-radius: 8px;
      -webkit-user-select: none;
      user-select: none;
      transition: all 0.2s ease;
      -webkit-touch-callout: none;
      pointer-events: auto;
    }
    img:active {
      opacity: 0.8;
    }
    table {
      border-collapse: collapse;
      width: 100%; 
      margin: 1.0em 0;
    }
    table, th, td {
      border: 1px solid #e0e0e0; 
    }
    th, td {
      padding: 8px;
      line-height: 1.6;
      font-size:0.8rem;
      text-align: justify;
    }
    th {
      background-color: ${tabColor};
      
    }
    tr:nth-child(even) {
      background-color: ${tabsColor};
    }
    blockquote{
      border-left: 4px solid #808080; 
      margin: 0.3em 0;
      padding: 0.3em 1em; 
      font-size: 0.8rem;
      line-height: 1.7;
      color: #555;
    }
    ul, ol {
      margin: 0.8em 0 0.8em 2em;
      padding-left: 0.1em;
      font-size: 0.8rem;
      line-height: 1.7;
    }
    li {
      margin: 0.1em 0;
    }
    li > p {
      margin: 0.1em 0;
    }
</style>
</head>
<body>
''' +
        // md.markdownToHtml(markdown)
        md.markdownToHtml(
          html,
          extensionSet: md.ExtensionSet.gitHubWeb,
          inlineSyntaxes: [
            md.StrikethroughSyntax(),
            md.EmojiSyntax(),
            md.AutolinkExtensionSyntax(),
            md.InlineHtmlSyntax(),
            // if (PrefService.getBool('single_line_break_syntax') ?? false)
            //   SingleLineBreakSyntax(),
          ],
          blockSyntaxes: [
            md.FencedCodeBlockSyntax(),
            md.HeaderWithIdSyntax(),
            md.SetextHeaderWithIdSyntax(),
            md.TableSyntax()
          ],
        ) +
        '''
<script src="file:///android_asset/flutter_assets/assets/preview/echarts.min.js"></script>
<script src="file:///android_asset/flutter_assets/assets/preview/mermaid.js"></script>
<script>mermaid.initialize({startOnLoad:true}, ".language-mermaid");</script>
<script src="file:///android_asset/flutter_assets/assets/preview/prism.js"></script>
  <script>
  document.querySelectorAll(".language-mermaid").forEach(function(entry) {
      entry.className="mermaid"
});
  mermaid.initialize({startOnLoad:true}, ".language-mermaid");
 
  function renderEcharts() {
   
    document.querySelectorAll(".language-echarts, .language-mindmap").forEach(function(container) {
      const chartDom = document.createElement('div');
      chartDom.style.width = '100%';
      chartDom.style.minHeight = '1000px';
      chartDom.style.margin = '10px 0';
      container.parentNode.replaceChild(chartDom, container);
      const myChart = echarts.init(chartDom);
      window.addEventListener('resize', function() {
        myChart.resize();
      });
      try {
        const option = JSON.parse(container.textContent.trim());
        myChart.setOption(option);
      } catch (e) {
        chartDom.innerHTML = `<div style="color: red; padding: 20px;">ECharts/Mindmap 配置解析失败</div>`;
      }
    });
  }
  window.onload = function() {
    if (window.Prism) Prism.highlightAll();
    renderEcharts();
  };
  </script>
  </body>
  </html>''';
    generatedPreview = generatedPreview
        .replaceAll('src="/', 'src="' + 'file:///')
        .replaceAll('src="/', 'src="' + 'file:///');
    // generatedPreview =
    //     generatedPreview.replaceAll('<img ', '<img width="100%" ');

    await webController?.loadData(data: generatedPreview);
  }

  Future<void> exec(final String js) async {
    if (webController == null) return;
    // 执行简单JS
    final result = await webController?.evaluateJavascript(
      source: js,
    );
    // 接收JS返回值
    if (result != null) {}
  }

  Future<void> _loadAssetsHtml() async {
    if (webController == null) return;
    await webController?.loadFile(assetFilePath: 'assets/editor/index.html');
    // await webController?.loadData(data: );

    // await webController?.evaluateJavascript(
    //   source: "javascript:ameClearCache();",
    // );
    // await webController?.evaluateJavascript(
    //   source: "javascript:ameDisabledCache();",
    // );
    // // await webController?.evaluateJavascript(
    // //   source: "javascript:ameFocus();",
    // // );

    // // 接收JS返回值
    // if (result != null) {}
    return;
  }

  // WebView配置选项
  final InAppWebViewGroupOptions _webViewOptions = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      // preferredContentMode: UserPreferredContentMode.MOBILE,
      horizontalScrollBarEnabled: false,
      verticalScrollBarEnabled: false,
      transparentBackground: true,
      // 新增：减少渲染延迟
      useOnLoadResource: false,
      supportZoom: false,
      // disableContextMenu: true,
      // 基础配置
      javaScriptEnabled: true, // 必须开启JS（绝大多数场景需要）
      useShouldOverrideUrlLoading: true, // 拦截URL跳转
      mediaPlaybackRequiresUserGesture: false, // 允许自动播放音频/视频
      // 文件访问配置
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      // 缓存配置
      cacheEnabled: true,
      clearCache: false,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true, // 视频内联播放
      allowsBackForwardNavigationGestures: true, // 侧滑前进/后退
    ),
    android: AndroidInAppWebViewOptions(
      // forceDark: AndroidForceDark.FORCE_DARK_AUTO,
      //  forceDarkStrategy: .WEB_CONTENT_MODE_DARK,
      // 3. 兼容混合内容（部分网页因混合内容导致配置失效）
      mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

      useHybridComposition: true, // 保留（Android 11+ 必需）
      // 关键优化：禁用WebView的过渡动画
      disableDefaultErrorPage: true,
      hardwareAcceleration: true, // 开启硬件加速，减少销毁卡顿
      // 禁用缩放动画（避免退出时页面缩小）
      builtInZoomControls: false,
      displayZoomControls: false,
      // 减少渲染缓存
      cacheMode: AndroidCacheMode.LOAD_CACHE_ELSE_NETWORK,
      // Android 11+ 必须开启，避免渲染问题
      allowContentAccess: true,
      // 隐藏原生缩放控件（自定义）
    ),
    // 修改InAppWebViewGroupOptions中的Android配置
  );

  /// 启动定时保存任务
  void _startSaveTimer() {
    // Timer.periodic 第一个参数是间隔时间（Duration），第二个是回调函数
    _saveTimer = Timer.periodic(Duration(seconds: _autoTimes), (timer) async {
      _saveContent(value: false); // 执行文件保存
    });
  }

  Color hexStringToColor(String hexStr, {String opacityHex = 'FF'}) {
    // 校验输入合法性，避免转换失败
    if (hexStr.length != 6) {
      throw ArgumentError("请传入6位的16进制颜色字符串，当前长度：${hexStr.length}");
    }
    if (opacityHex.length != 2) {
      throw ArgumentError("透明度必须是2位16进制字符串，当前长度：${opacityHex.length}");
    }
    // 拼接透明度和RGB，得到完整的8位十六进制字符串
    String fullHex = opacityHex + hexStr;
    // 将十六进制字符串转为整数（radix=16 指定十六进制）
    int colorValue = int.parse(fullHex, radix: 16);
    // 构建并返回 Color 对象
    return Color(colorValue);
  }

  /// 取消定时保存任务
  void _cancelSaveTimer() {
    if (_saveTimer != null && _saveTimer!.isActive) {
      _saveTimer!.cancel();
      _saveTimer = null;
    }
  }

  Widget buildTocList() => TocWidget(controller: controller);
  // 新建MD文件弹窗
  Future<void> _showChatDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "edit_hint_question".tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 监听流式响应
              _answer = "";
              final stream = _api.streamChat(
                  controller.text, Utils.getAiConfig()['model'].toString());
              await for (final content in stream) {
                setState(() {
                  _answer += content;
                  // _controller.text = _controller.text + content;
                  // _insertMarkdown(content);
                  _wrapMarkdown(prefix: content, suffix: '');
                  // _scrollController.animateTo(
                  //   _scrollController.position.maxScrollExtent,
                  //   duration: const Duration(milliseconds: 100),
                  //   curve: Curves.easeOut,
                  // );
                });
                // 自动滚动到底部
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  // 原有方法：单个删除（保留）
  Future<void> _showSaveModelConfirmDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("保存模板"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "输入模板名"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FileUtils.saveModelToDir(
                    widget.filePath, controller.text, _controller.text);
                Utils.showToast(context, "保存成功");
              } catch (e) {
                if (mounted) {
                  Utils.showToast(context, 'delete_failed'.tr());
                }
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 正确：在didChangeDependencies中获取MediaQuery
    // isDark = MediaQuery.of(context).platformBrightness;
    // 注册观察者
    // isDark = Provider.of<ThemeProvider>(context, listen: false)
    //     .getSystemBrightness(context);
    // Utils.showToast(context, "message" + isDark.toString());
    // Consumer<ThemeProvider>(builder: (context, provider, child) {
    //   return;
    // });
    // 判断是否为深色模式
  }

  @override
  void initState() {
    super.initState();
    _loadFiles("md_model");
    _theme = ThemeUtil.getIsDark();
    // _checkPermissions().then((granted) {
    //   if (granted) {
    //     _initSpeech();
    //   }
    // });
    _render = config['mark_render'] != null ? config['mark_render'] : "";
    _quoteTextColor =
        config['quote_text_color'] != null ? config['quote_text_color'] : "";
    _switchValue1 = config['view_count'] != null ? config['view_count'] : true;
    _linkColor = config['link_color'] != null ? config['link_color'] : "";
    _quoteColor = config['quote_color'] != null ? config['quote_color'] : "";
    _codeFontColor =
        config['code_font_color'] != null ? config['code_font_color'] : "";
    _codeBgColor =
        config['code_bg_color'] != null ? config['code_bg_color'] : "";
    _imageQuality =
        config['image_quality'] != null ? config['image_quality'] : 80;
    _autoTimes = config['auto_times'] != null ? config['auto_times'] : 5;
    _fontSize = config['font_size'] != null ? config['font_size'] : 12.0;
    switch (_imageQuality) {
      case 80:
        _filterQuality = FilterQuality.medium;
        break;
      case 60:
        _filterQuality = FilterQuality.low;
        break;
      case 100:
        _filterQuality = FilterQuality.high;
        break;
      default:
        _filterQuality = FilterQuality.high;
    }

    _githubRepoController = TextEditingController(text: gitConfig['repo']);
    _githubBranchController = TextEditingController(text: gitConfig['branch']);
    _startSaveTimer();
    _focusNode = FocusNode();
    _initController();
    // 延迟更长时间，确保布局完全稳定（解决渲染时机问题）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 额外延迟200ms，适配复杂布局的渲染
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isWidgetReady = true;
          });
        }
      });
    });
  }

  // 参考官方示例：初始化编辑器控制器
  Future<void> _initController() async {
    _isLoading = true;
    final content = await FileUtils.readMdFile(widget.filePath);
    _isEmpty = content.isEmpty;
    setState(() {
      if (_isEmpty) {
        _isPreview = false;
        _isToolBarVisible = true;
        _isEdit = true;
      } else {
        if (_render != 3) {
          _isPreview = true;
          _isToolBarVisible = false;
        } else {
          _isToolBarVisible = true;
        }

        _isEdit = false;
      }
      _isLoading = false;
      _controller.text = content;
      _lengthNotifier.value = _controller.text.length;
    });
    _controller.addListener(() {
      setState(() {
        _lengthNotifier.value = _controller.text.length;
      });
    });
    // 官方推荐的 Markdown 加载方式
  }

  // 参考官方示例：保存为 Markdown
  Future<void> _saveContent({bool value = true}) async {
    if (_isSaving) return;
    if (_render == 3) {
      if (webController == null) return;
      // 执行简单JS
      final result = await webController?.evaluateJavascript(
        source: 'javascript:vditor.getValue();',
      );
      // 接收JS返回值
      if (result != null) {
        bool isSuccess = await FileUtils.saveMdFile(widget.filePath, result);
        setState(() {
          _isSaving = true;
          if (value) {
            if (isSuccess) {
              Utils.showToast(context, 'save_success'.tr());
            } else {
              Utils.showToast(context, 'save_failed'.tr());
            }
          }
        });
        try {} catch (e) {
          if (mounted) {
            Utils.showToast(context, 'save_failed'.tr());
          }
        } finally {
          setState(() => _isSaving = false);
        }
      }
      return;
    } else {
      try {
        bool isSuccess =
            await FileUtils.saveMdFile(widget.filePath, _controller.text);
        setState(() {
          _isSaving = true;
          if (value) {
            if (isSuccess) {
              Utils.showToast(context, 'save_success'.tr());
            } else {
              Utils.showToast(context, 'save_failed'.tr());
            }
          }
        });
      } catch (e) {
        if (mounted) {
          Utils.showToast(context, 'save_failed'.tr());
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
    // 自动备份
    if (Utils.getBackupsConfig()['is_auto']) {
      final file = File(widget.filePath);
      bool upload = await Webdav.uploadFile(file);
    }
  }

  /// 打开配置弹窗
  void _openGitConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // 适配小屏幕滚动
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _githubRepoController,
                decoration: InputDecoration(
                  labelText: "github_repo".tr(),
                  hintText: "github_repo_hint".tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, size: 18),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _githubBranchController,
                decoration: InputDecoration(
                  labelText: "github_branch".tr(),
                  hintText: "github_branch_hint".tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key, size: 18),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                "github_tip".tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          TextButton(
            onPressed: () async {
              final repo = _githubRepoController.text.trim();
              final branch = _githubBranchController.text.trim();
              if (repo.isEmpty || branch.isEmpty) {
                Utils.showToast(context, "github_isEmpty".tr());
              } else {
                // 模拟加载完成，3秒后关闭
                Utils.saveGitConfig(
                  isDialog: Utils.getGitConfig()['dialog'],
                  message: Utils.getGitConfig()['message'],
                  repo: repo,
                  branch: branch,
                  imagePath: Utils.getGitConfig()['image'],
                );
                DialogWidget.show(context: context);
                bool isSuccess = await _publishContent(
                    repo, branch, Utils.getGitConfig()['message']);
                if (isSuccess) {
                  DialogWidget.dismiss(context);
                } else {
                  DialogWidget.dismiss(context);
                }
              }
            },
            child: Text("confirm".tr()),
          ),
        ],
      ),
    );
  }

  Future<bool> _publishContent(
      String githubRepo, String branch, String message) async {
    try {
      Map<String, dynamic> res =
          await GithubApi.isRepoExist(githubRepo: githubRepo);
      if (res["isExist"] == false) {
        try {
          bool isSuccess = await GithubApi.createRepo(githubRepo, "Gitdiary");
          if (isSuccess) {
            final file = File(widget.filePath);
            final content = await FileUtils.readMdFile(widget.filePath);
            try {
              Map<String, dynamic> isSuccess = await GithubApi.uploadFile(
                fileName: file.path.split('/').last,
                content: content,
                githubRepo: githubRepo,
                branch: branch,
                message: message,
              );
              setState(() {
                Utils.showToast(context, 'publish_success'.tr());
              });
              return true;
            } catch (e) {
              Utils.showToast(context, 'publish_failed'.tr());
              return false;
            } finally {
              setState(() {
                Utils.showToast(context, 'publish_failed'.tr());
              });
            }
          }
        } catch (e) {
          Utils.showToast(context, 'publish_failed'.tr());
          return false;
        }
      } else {
        final file = File(widget.filePath);
        final content = await FileUtils.readMdFile(widget.filePath);
        try {
          Map<String, dynamic> isSuccess = await GithubApi.uploadFile(
            fileName: file.path.split('/').last,
            content: content,
            githubRepo: githubRepo,
            branch: branch,
            message: message,
          );
          setState(() {
            Utils.showToast(context, 'publish_success'.tr());
          });
          return true;
        } catch (e) {
          Utils.showToast(context, 'publish_failed'.tr());
          return false;
        } finally {
          setState(() {
            Utils.showToast(context, 'publish_failed'.tr());
          });
        }
      }
    } catch (e) {
      Utils.showToast(context, 'publish_failed'.tr());
      return false;
    }
    return false;
  }

  void _insertMarkdown(String markdown) async {
    final text = _controller.text;
    final selection = _controller.selection;
    // 1. 标准化选择范围：处理用户反向选择（从后往前选）的情况
    final effectiveStart = math.min(selection.start, selection.end);
    final effectiveEnd = math.max(selection.start, selection.end);

    // 2. 正确替换：仅用 markdown 替换选中区域，不手动拼接末尾内容
    final newText = text.replaceRange(
      effectiveStart,
      effectiveEnd,
      markdown, // 核心修复：移除多余的 text.substring(selection.end)
    );
    // 3. 更新文本控制器
    _controller.text = newText;
    // 4. 修正光标位置：折叠光标到 markdown 插入后的末尾（更符合交互习惯）
    final newCursorOffset = effectiveStart + markdown.length;
    _controller.selection = TextSelection.collapsed(offset: newCursorOffset);
  }

  BoxDecoration get(int depth) {
    if (depth == 0) {
      return BoxDecoration(
        shape: BoxShape.circle,
      );
    } else if (depth == 1) {
      return BoxDecoration(
        border: Border.all(),
        shape: BoxShape.circle,
      );
    }
    return BoxDecoration();
  }

  Future<void> _pickImageFromGalleryToUpdata() async {
    try {
      // 调用图库选择图片（可指定图片类型/质量，这里用默认）
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery, // 选择图库（相机用 ImageSource.camera）
        imageQuality: 80, // 图片质量（0-100）
      );

      if (pickedImage != null) {
        DialogWidget.show(context: context);
        final file = await FileUtils.saveImageToDir(pickedImage);
        if (file == null) {
          DialogWidget.dismiss(context);
          Utils.showToast(context, "import_failed".tr());
        } else {
          DialogWidget.dismiss(context);
          try {
            String imageUrl = await GithubApi.uploadImage(file);
            String name = pickedImage.name;
            _wrapMarkdown(
              prefix: '![$name',
              suffix: ']($imageUrl)',
              placeholder: 'image_placeholder'.tr(),
            );
            DialogWidget.dismiss(context);
          } catch (e) {
            Utils.showToast(context, 'updata_image_failed'.tr());
            DialogWidget.dismiss(context);
            return;
          }
        }
      }
    } catch (e) {
      // 捕获异常（如权限拒绝、取消选择等）
      if (mounted) {
        Utils.showToast(context, 'image_picker_failed'.tr());
      }
    }
  }

  // 选择图片的核心方法：调用图库并处理结果
  Future<void> _pickImageFromGallery() async {
    try {
      // 调用图库选择图片（可指定图片类型/质量，这里用默认）
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery, // 选择图库（相机用 ImageSource.camera）
        imageQuality: _imageQuality, // 图片质量（0-100）
      );

      if (pickedImage != null) {
        DialogWidget.show(context: context);
        final file = await FileUtils.saveImageToDir(pickedImage);
        if (file == null) {
          DialogWidget.dismiss(context);
          Utils.showToast(context, "import_failed".tr());
        } else {
          DialogWidget.dismiss(context);
          try {
            String imageUrl = file.path;
            String name = pickedImage.name;
            _wrapMarkdown(
              prefix: '![$name',
              suffix: ']($imageUrl)',
              placeholder: 'image_placeholder'.tr(),
            );
            DialogWidget.dismiss(context);
          } catch (e) {
            Utils.showToast(context, 'updata_image_failed'.tr());
            DialogWidget.dismiss(context);
            return;
          }
        }
      }
    } catch (e) {
      // 捕获异常（如权限拒绝、取消选择等）
      if (mounted) {
        Utils.showToast(context, 'image_picker_failed'.tr());
      }
    }
  }

  // 弹出选择弹窗：输入链接 / 选择图片
  void _showImageOptionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'image_insert'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text('edit_image_link'.tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  _wrapMarkdown(
                    prefix: '![图片链接',
                    suffix: '](url)',
                    placeholder:
                        'image_placeholder'.tr(), // 光标默认在「图片描述」位置，也可调整到 url 处
                    // 如需光标定位到 url：可修改 wrapMarkdown 或手动调整 cursorOffset
                    // 示例（手动调整光标）：
                    // _wrapMarkdown(prefix: '![图片描述](', suffix: ')', placeholder: 'url');
                  );
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('select_from_gallery'.tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _pickImageFromGallery(); // 调用图库选择方法
                },
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.image_sharp),
                title: Text('upload_image_to_repo'.tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _pickImageFromGalleryToUpdata(); // 调用图库选择方法
                },
              ),
            ),
            // 取消按钮
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    child: Center(
                        child: Text('cancel'.tr(),
                            style: TextStyle(color: Colors.red)))),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Widget buildMarkdown() => MarkdownWidget(data: data);
  void _wrapMarkdown({
    required String prefix, // 前缀标记（如 **）
    required String suffix, // 后缀标记（如 **）
    String placeholder = '', // 无选中时的占位符（如输入 ** 后光标在中间）
  }) async {
    if (_render == 3) {
      exec("javascript:insertValue('" +
          base64Encode(utf8.encode(prefix + suffix)) +
          "');");
      return;
    }
    final text = _controller.text;
    final selection = _controller.selection;
    final effectiveStart = math.min(selection.start, selection.end);
    final effectiveEnd = math.max(selection.start, selection.end);

    // 选中的文本内容
    final selectedText = text.substring(effectiveStart, effectiveEnd);

    // 替换逻辑：有选中则包裹，无选中则插入占位符并定位光标
    String replacement;
    int cursorOffset;
    if (selectedText.isNotEmpty) {
      replacement = '$prefix$selectedText$suffix';
      cursorOffset = effectiveStart + replacement.length;
    } else {
      replacement = '$prefix$placeholder$suffix';
      cursorOffset = effectiveStart + prefix.length; // 光标定位到前后缀之间
    }

    _controller.text =
        text.replaceRange(effectiveStart, effectiveEnd, replacement);
    _controller.selection = TextSelection.collapsed(offset: cursorOffset);
  }

  /// 增强版截图方法：解决截图区域获取失败
  Future<Uint8List?> _captureWidget() async {
    if (!_isWidgetReady) {
      if (mounted) {
        Utils.showToast(context, 'screenshot_area_not_rendered'.tr());
        return null;
      }
      return null;
    }

    // 调试信息：打印Key的上下文状态（方便排查问题）

    try {
      // 步骤1：检查Key的上下文是否存在
      if (_captureKey.currentContext == null) {
        if (mounted) {
          Utils.showToast(context, "screenshot_area_context_lost".tr());
        }
        return null;
      }

      // 步骤2：等待渲染对象稳定（增加更长的延迟，适配复杂布局）
      await Future.delayed(const Duration(milliseconds: 300));

      // 步骤3：安全获取渲染对象（多次尝试，提高成功率）
      RenderRepaintBoundary? boundary;
      int retryCount = 0;
      while (boundary == null && retryCount < 3) {
        retryCount++;

        final renderObject = _captureKey.currentContext?.findRenderObject();
        if (renderObject is RenderRepaintBoundary) {
          boundary = renderObject;
        } else {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (boundary == null) {
        if (mounted) {
          Utils.showToast(context, "screenshot_area_failed".tr());
        }
        return null;
      }

      // 步骤4：生成图片（增加像素比检查，避免参数异常）
      final pixelRatio =
          MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          Utils.showToast(context, "image_convert_failed".tr());
        }
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      if (mounted) {
        Utils.showToast(context, "screenshot_failed".tr());
      }
      return null;
    }
  }

  /// 保存图片到临时目录
  Future<File?> _saveImageToTempDir(Uint8List imageBytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'share.png';
      final imagePath = path.join(directory.path, fileName);
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      if (await imageFile.exists()) {
        return imageFile;
      } else {
        if (mounted) {
          Utils.showToast(context, "file_create_failed".tr());
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        Utils.showToast(context, "file_save_failed".tr());
      }
      return null;
    }
  }

  Future<void> _shareText() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      await Share.share(_controller.text);

      if (mounted) {
        Utils.showToast(context, "share_text_success".tr());
      }
    } catch (e) {
      if (mounted) {
        Utils.showToast(context, "share_text_failed".tr());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  /// 分享图片
  Future<void> _shareImage() async {
    if (_isSharing || !_isWidgetReady) return;

    setState(() {
      _isSharing = true;
    });

    try {
      Uint8List? imageBytes = await _captureWidget();
      if (imageBytes == null) return;

      File? imageFile = await _saveImageToTempDir(imageBytes);
      if (imageFile == null) return;

      await Share.shareXFiles(
        [XFile(imageFile.path)],
      );

      if (mounted) {
        Utils.showToast(context, "share_image_success".tr());
      }
    } catch (e) {
      if (mounted) {
        Utils.showToast(context, "share_image_failed".tr());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

// // 调用示例：加粗选中文字
// _wrapMarkdown(prefix: '**', suffix: '**');
// // 调用示例：插入链接（无选中时显示 [链接文本](链接地址)）
// _wrapMarkdown(prefix: '[', suffix: '](链接地址)', placeholder: '链接文本');
  @override
  void dispose() {
    _cancelSaveTimer();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 核心：获取当前生效的亮度模式
    // Brightness currentBrightness = MediaQuery.of(context).platformBrightness;
    // // 判断是否为深色模式
    // isDark = currentBrightness;
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // 自定义退出逻辑：先隐藏WebView，再执行退出
        setState(() {
          // 设置状态使WebView隐藏
          _cancelSaveTimer();
          _isLoading = true;
        });
        // _saveContent(value: false);
        Provider.of<GitProvider>(context, listen: false).refresh();
        // 延迟一小段时间，让UI更新
        // await Future.delayed(const Duration(milliseconds: 100));
        // 释放WebView资源
        // await _disposeWebViewResources();
        // 执行退出
        if (mounted) {
          Navigator.pop(context);
        }
      },

      // 延迟一小段时间，让UI更新
      // await Future.delayed(const Duration(milliseconds: 100));
      // 释放WebView资源
      // await _disposeWebViewResources();
      // 执行退出

      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName ?? 'rich_text_editor'.tr()),
          actions: [
            if (_isPreview)
              Padding(
                padding: const EdgeInsets.only(right: 0),
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isPreview = false;
                      _isToolBarVisible = true;
                    });
                  },
                  tooltip: 'edit'.tr(),
                ),
              ),
            if (_render == 0)
              Padding(
                padding: const EdgeInsets.only(right: 0),
                child: IconButton(
                  icon: const Icon(Icons.format_line_spacing_outlined),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (context) => buildTocList(),
                    );
                  },
                  tooltip: 'save'.tr(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.publish),
                onPressed: () async {
                  if (Utils.getGitConfig()['dialog'] == true) {
                    _openGitConfigDialog();
                  } else {
                    DialogWidget.show(context: context);
                    bool isSuccess = await _publishContent(
                        Utils.getGitConfig()['repo'],
                        Utils.getGitConfig()['branch'],
                        Utils.getGitConfig()['message']);
                    if (isSuccess) {
                      DialogWidget.dismiss(context);
                    } else {
                      DialogWidget.dismiss(context);
                    }
                  }
                },
                tooltip: 'publish'.tr(),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.only(right: 0),
            //   child: PopupMenuButton<String>(
            //     elevation: 1,
            //     onSelected: (value) {
            //       if (value == 'share_image') {
            //         _shareImage();
            //       } else if (value == 'share_text') {
            //         _shareText();
            //       }
            //     },
            //     itemBuilder: (context) => [
            //       PopupMenuItem(
            //         value: 'share_image',
            //         child: ListTile(
            //           leading: Icon(Icons.image),
            //           title: Text('share_as_image'.tr()),
            //         ),
            //       ),
            //       PopupMenuItem(
            //         child: ListTile(
            //           leading: Icon(Icons.text_snippet_sharp),
            //           title: Text('share_as_text'.tr()),
            //           onTap: () {
            //             Navigator.pop(context); // 关闭弹窗
            //             _shareText();
            //           },
            //         ),
            //       ),
            //     ],
            //     icon: const Icon(Icons.more_vert),
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: IconButton(
                icon: Icon(Icons.move_to_inbox_outlined),
                onPressed: () async {
                  _showSaveModelConfirmDialog();
                },
                tooltip: 'save'.tr(),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: const CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.max, // 关键：Column仅占需要的高度
                children: [
                  Expanded(
                    child: _isPreview
                        ? // 预览模式：修复滚动组件高度问题
                        RepaintBoundary(
                            key: _captureKey,
                            // child: Container(
                            // width: double.infinity, // 占满宽度
                            // 关键：给SingleChildScrollView添加明确的高度约束
                            child: _render == 0
                                ? MarkdownWidget(
                                    tocController: controller,
                                    markdownGenerator: MarkdownGenerator(
                                      generators: [
                                        videoGeneratorWithTag,
                                        // latexGenerator
                                      ],
                                      inlineSyntaxList: [
                                        // LatexSyntax(),
                                        // AutolinkNoLeadingSpaceSyntax(),
                                      ],
                                      // inlineSyntaxList: [LatexSyntax()],
                                      textGenerator: (node, config, visitor) =>
                                          CustomTextNode(node.textContent,
                                              config, visitor),
                                      richTextBuilder: (span) =>
                                          Text.rich(span),
                                    ),
                                    padding: EdgeInsets.all(10),
                                    physics: const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                                    shrinkWrap: true,
                                    data: _controller.text,
                                    config: MarkdownConfig(
                                      configs: [
                                        // PreConfig(
                                        //     textStyle: TextStyle(
                                        //         color: hexStringToColor(
                                        //             _codeFontColor != ""
                                        //                 ? _codeFontColor
                                        //                 : Colors.black.value
                                        //                     .toRadixString(16)
                                        //                     .substring(2)))),
                                        H1Config(
                                            style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold)),
                                        ListConfig(
                                          marginLeft: 32.0,
                                          marginBottom: 4.0,
                                          marker: (isOrdered, depth, index) {
                                            if (isOrdered) {
                                              return Container(
                                                  alignment: Alignment.center,
                                                  padding:
                                                      EdgeInsets.only(right: 1),
                                                  child: SelectionContainer
                                                      .disabled(
                                                          child: Text(
                                                    '${index + 1}.',
                                                    style: TextStyle(
                                                        fontSize: _fontSize),
                                                  )));
                                            }
                                          },
                                        ),
                                        TableConfig(
                                          defaultColumnWidth:
                                              FlexColumnWidth(1),
                                          // defaultVerticalAlignment:
                                          //     TableCellVerticalAlignment.fill,
                                          // 1. 表格整体边框配置
                                          border: TableBorder(
                                            top: BorderSide(
                                                color: Colors.grey, width: 1),
                                            right: BorderSide(
                                                color: Colors.grey, width: 1),
                                            bottom: BorderSide(
                                                color: Colors.grey, width: 1),
                                            left: BorderSide(
                                                color: Colors.grey, width: 1),
                                            borderRadius: BorderRadius.circular(
                                                8), // 表格圆角
                                            horizontalInside: BorderSide(
                                                color: Colors.grey, width: 1),
                                            verticalInside: BorderSide(
                                                color: Colors.grey, width: 1),
                                          ),
                                          // 2. 单元格内边距
                                          bodyPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          // 3. 表格内容文字样式
                                          bodyStyle: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                          // 4. 表头配置（最关键的区分项）
                                        ),
                                        // HrConfig(height: 10.0, color: Colors.blue),
                                        PreConfig(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            // backgroundBlendMode: BlendMode.darken,
                                            border: Border.all(
                                                color: hexStringToColor(
                                                    _codeBgColor != ""
                                                        ? _codeBgColor
                                                        : Colors.black.value
                                                            .toRadixString(16)
                                                            .substring(2))),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        BlockquoteConfig(
                                            textColor: hexStringToColor(
                                                _quoteTextColor != ""
                                                    ? _quoteTextColor
                                                    : Colors.grey.value
                                                        .toRadixString(16)
                                                        .substring(2)),
                                            sideColor: hexStringToColor(
                                                _quoteColor != ""
                                                    ? _quoteColor
                                                    : Colors.grey.value
                                                        .toRadixString(16)
                                                        .substring(2))),
                                        CodeConfig(
                                            style: TextStyle(
                                          fontSize: _fontSize,
                                          color: hexStringToColor(
                                              _codeFontColor != ""
                                                  ? _codeFontColor
                                                  : Colors.black.value
                                                      .toRadixString(16)
                                                      .substring(2)),
                                          backgroundColor: const Color.fromARGB(
                                              0, 146, 7, 7),
                                          fontStyle: FontStyle.normal,
                                        )),
                                        PConfig(
                                            textStyle: TextStyle(
                                          fontSize: _fontSize,
                                          // color: isDark == Brightness.dark
                                          //     ? Colors.black
                                          //     : Colors.white,
                                        )),

                                        CheckBoxConfig(
                                          builder: (checked) {
                                            // return Transform.scale(
                                            //   // 缩放比例：基于baseFontSize，视觉上与文字大小一致
                                            //   // 可根据需要调整（如0.95/1.05）
                                            //   scale: _fontSize /
                                            //       18, // 18是Flutter默认Checkbox的基础尺寸
                                            //   child: Checkbox(
                                            //     // 复选框选中状态
                                            //     value: checked,
                                            //     // 禁用点击（Markdown的复选框默认仅展示，无需交互）
                                            //     onChanged: null,
                                            //     // 复选框尺寸（基础尺寸，配合scale精准控制）
                                            //     materialTapTargetSize:
                                            //         MaterialTapTargetSize.shrinkWrap,
                                            //     // 选中时的颜色
                                            //     activeColor: Colors.blueAccent,
                                            //     // 选中标记的颜色
                                            //     checkColor: Colors.white,
                                            //     // 未选中时的边框颜色
                                            //     side: BorderSide(
                                            //       color: Colors.grey[400]!,
                                            //       width: 1,
                                            //     ),
                                            //   ),
                                            // );
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .center, // 垂直居中核心
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              verticalDirection:
                                                  VerticalDirection.down,
                                              children: [
                                                SizedBox(
                                                  // width: double.maxFinite,
                                                  // height: double.maxFinite,
                                                  // width: 20, // 固定checkbox宽度，避免尺寸波动
                                                  // height: 20, // 固定高度，匹配文字行高
                                                  child: Checkbox(
                                                    value: checked,
                                                    // 移除默认内边距，缩小checkbox尺寸
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    // 取消点击水波纹的额外尺寸
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    // 调整checkbox的padding（关键，去掉默认边距）
                                                    // 自定义checkbox颜色（可选）
                                                    activeColor: Colors.grey,
                                                    checkColor: Colors.white,
                                                    onChanged: (bool? value) {
                                                      setState(() {
                                                        value = value!;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                // 给checkbox和文字加少量间距
                                                const SizedBox(width: 1),
                                              ],
                                            );
                                          },
                                        ),
                                        ImgConfig(
                                          errorBuilder: (url, alt, error) {
                                            return const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 30,
                                            );
                                          },
                                          builder: (url, attributes) {
                                            return ClipRRect(
                                              clipBehavior: Clip.antiAlias,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: url
                                                          .toString()
                                                          .startsWith('http') ||
                                                      url
                                                          .toString()
                                                          .startsWith('https')
                                                  ? Center(
                                                      child: CachedNetworkImage(
                                                      filterQuality:
                                                          _filterQuality,
                                                      imageUrl: url.toString(),
                                                      fit: BoxFit
                                                          .cover, // 确保图片覆盖整个容器
                                                      alignment: Alignment
                                                          .center, // 确保图片居中
                                                      // 加载中占位
                                                      placeholder:
                                                          (context, url) =>
                                                              Container(
                                                        // 获取屏幕宽度，同时作为宽高，实现屏幕宽度的正方形
                                                        width: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        height: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        child: Card(
                                                          // 浅灰色背景，可按需调整深浅（100更浅/300稍深）
                                                          color:
                                                              Colors.grey[200],
                                                          // 圆角设置，半径可按需调整（如12/16）
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          // 取消卡片默认边距和无阴影，贴合需求
                                                          margin:
                                                              EdgeInsets.zero,
                                                          elevation: 0,
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              // 加载圈灰色，适配浅灰背景，可删恢复默认蓝色
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // 加载失败占位
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Column(
                                                        children: [
                                                          Image.asset(
                                                              'assets/images/error.png'),
                                                        ],
                                                      ),
                                                    ))
                                                  : Image.file(
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Column(
                                                          children: [
                                                            Image.asset(
                                                                'assets/images/error.png')
                                                          ],
                                                        );
                                                      },
                                                      File(url.toString()),
                                                      filterQuality:
                                                          _filterQuality,
                                                      fit: BoxFit
                                                          .cover, // 确保图片覆盖整个容器
                                                      alignment: Alignment
                                                          .center, // 确保图片居中
                                                    ),
                                            );
                                          },
                                        ),
                                        LinkConfig(
                                          style: TextStyle(
                                              fontSize: _fontSize,
                                              color: hexStringToColor(
                                                  _linkColor != ""
                                                      ? _linkColor
                                                      : Colors.blue.value
                                                          .toRadixString(16)
                                                          .substring(2))),
                                          onTap: (url) {
                                            ///TODO:on tap
                                            launchUrl(Uri.parse(url ?? ''));
                                          },
                                        )
                                      ],
                                    ),
                                  )
                                : _render == 1
                                    ? SingleChildScrollView(
                                        padding: EdgeInsets.all(16),
                                        physics: const BouncingScrollPhysics(
                                          parent:
                                              AlwaysScrollableScrollPhysics(),
                                        ),
                                        child: md.MarkdownBody(
                                          inlineSyntaxes: [
                                            md.InlineHtmlSyntax(), // 核心：解析Emoji表情
                                          ],
                                          blockSyntaxes: [
                                            md.HtmlBlockSyntax(), // 核心：解析块级 HTML
                                          ],
                                          checkboxBuilder: (value) =>
                                              GestureDetector(
                                            onHorizontalDragStart:
                                                (DragStartDetails details) {
                                              // 处理水平拖动开始事件
                                            },
                                            // 关键：用Row包裹Checkbox+透明占位，调整对齐和尺寸
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .center, // 垂直居中核心
                                              children: [
                                                SizedBox(
                                                  width:
                                                      20, // 固定checkbox宽度，避免尺寸波动
                                                  height: 20, // 固定高度，匹配文字行高
                                                  child: Checkbox(
                                                    value: value,
                                                    // 移除默认内边距，缩小checkbox尺寸
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    // 取消点击水波纹的额外尺寸
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    // 调整checkbox的padding（关键，去掉默认边距）
                                                    // 自定义checkbox颜色（可选）
                                                    activeColor: Colors.grey,
                                                    checkColor: Colors.white,
                                                    onChanged: (bool? value) {
                                                      setState(() {
                                                        value = value!;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                // 给checkbox和文字加少量间距
                                                const SizedBox(width: 2),
                                              ],
                                            ),
                                          ),

                                          bulletBuilder: (index, style) => Text(
                                            '•',
                                            style: TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          styleSheetTheme: md
                                              .MarkdownStyleSheetBaseTheme
                                              .material,
                                          styleSheet: md.MarkdownStyleSheet(
                                            textScaler: TextScaler.linear(1.2),
                                            tableCellsPadding:
                                                EdgeInsets.all(8),
                                            tableHeadAlign: TextAlign.center,
                                            listIndent: 24,
                                            listBullet: const TextStyle(
                                              fontSize: 20,
                                            ),
                                            tableBody: const TextStyle(
                                              fontSize: 12,
                                              fontFamily:
                                                  AutofillHints.addressCity,
                                              fontStyle: FontStyle.normal,
                                            ),
                                            blockSpacing: 12,
                                            blockquotePadding:
                                                EdgeInsets.all(8),
                                            blockquoteAlign:
                                                WrapAlignment.start,
                                            blockquote: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                            blockquoteDecoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: hexStringToColor(
                                                      _quoteColor != ""
                                                          ? _quoteColor
                                                          : Colors.black.value
                                                              .toRadixString(16)
                                                              .substring(2)),
                                                  width: 3,
                                                ),
                                              ),
                                              // borderRadius: BorderRadius.circular(4),
                                            ),
                                            codeblockAlign:
                                                WrapAlignment.center,
                                            codeblockPadding: EdgeInsets.all(8),

                                            codeblockDecoration: BoxDecoration(
                                              color:
                                                  Colors.grey.withOpacity(0.1),
                                              // backgroundBlendMode: BlendMode.darken,
                                              border: Border.all(
                                                  color: hexStringToColor(
                                                      _codeBgColor != ""
                                                          ? _codeBgColor
                                                          : Colors.black.value
                                                              .toRadixString(16)
                                                              .substring(2))),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            em: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            strong: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily:
                                                  AutofillHints.addressCity,
                                              fontStyle: FontStyle.normal,
                                            ),
                                            h1: const TextStyle(
                                              fontSize: 20,
                                            ),
                                            h2: const TextStyle(
                                              fontSize: 18,
                                            ),
                                            h3: const TextStyle(
                                              fontSize: 16,
                                            ),
                                            h4: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            h5: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            h6: const TextStyle(
                                              fontSize: 10,
                                            ),
                                            p: TextStyle(
                                              fontSize: _fontSize,
                                            ),
                                            code: TextStyle(
                                              fontSize: 10,
                                              color: hexStringToColor(
                                                  _codeFontColor != ""
                                                      ? _codeFontColor
                                                      : Colors.black.value
                                                          .toRadixString(16)
                                                          .substring(2)),
                                              backgroundColor:
                                                  Colors.transparent,
                                              // Color.fromRGBO(158, 158, 158, 1),
                                              // color: Color.fromARGB(255, 24, 241, 38),
                                              // fontFamily: AutofillHints.addressCity,
                                              fontStyle: FontStyle.normal,
                                            ),

                                            // 自定义链接样式
                                            a: TextStyle(
                                                fontSize: _fontSize,
                                                color: hexStringToColor(
                                                    _linkColor != ""
                                                        ? _linkColor
                                                        : Colors.grey.value
                                                            .toRadixString(16)
                                                            .substring(2))),

                                            // 自定义任务列表复选框样式
                                            checkbox: const TextStyle(
                                              color: Colors.grey,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              fontStyle: FontStyle.normal,
                                            ),
                                          ),
                                          builders: {},
                                          extensionSet: md.ExtensionSet(
                                            // md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                                            // md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                                            // 第2个参数：复用 GitHub 行内语法 + 新增 Emoji/HTML 语法
                                            // 块级语法：添加 BlockHtmlSyntax 解析块级 HTML
                                            [
                                              md.HtmlBlockSyntax(), // 核心：解析块级 HTML
                                              ...md.ExtensionSet.gitHubWeb
                                                  .blockSyntaxes,
                                            ],
                                            [
                                              md.EmojiSyntax(), // 表情语法（行内）
                                              md.InlineHtmlSyntax(), // HTML 语法（行内，解析<img>等标签需要）
                                              ...md.ExtensionSet.gitHubWeb
                                                  .inlineSyntaxes, // 保留 GitHub 默认行内语法
                                            ],
                                            // 启用 HTML 语法解析
                                          ),
                                          imageBuilder: (uri, title, alt) {
                                            return ClipRRect(
                                              clipBehavior: Clip.antiAlias,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: uri
                                                      .toString()
                                                      .startsWith('http')
                                                  ? Center(
                                                      child: CachedNetworkImage(
                                                      filterQuality:
                                                          _filterQuality,
                                                      // imageBuilder:
                                                      //     (context, imageProvider) =>
                                                      //         Container(
                                                      //   decoration: BoxDecoration(
                                                      //     image: DecorationImage(
                                                      //       image: imageProvider,
                                                      //       fit: BoxFit.cover,
                                                      //     ),
                                                      //   ),
                                                      // ),
                                                      imageUrl: uri.toString(),
                                                      fit: BoxFit
                                                          .cover, // 确保图片覆盖整个容器
                                                      alignment: Alignment
                                                          .center, // 确保图片居中
                                                      // 加载中占位
                                                      placeholder: (context,
                                                              url) =>
                                                          // 屏幕宽度的正方形、浅灰色圆角加载卡片
                                                          Container(
                                                        // 获取屏幕宽度，同时作为宽高，实现屏幕宽度的正方形
                                                        width: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        height: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        child: Card(
                                                          // 浅灰色背景，可按需调整深浅（100更浅/300稍深）
                                                          color:
                                                              Colors.grey[200],
                                                          // 圆角设置，半径可按需调整（如12/16）
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          // 取消卡片默认边距和无阴影，贴合需求
                                                          margin:
                                                              EdgeInsets.zero,
                                                          elevation: 0,
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              // 加载圈灰色，适配浅灰背景，可删恢复默认蓝色
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      // progressIndicatorBuilder: (context,
                                                      //         url, downloadProgress) =>
                                                      //     Center(
                                                      //   child: CircularProgressIndicator(
                                                      //     value:
                                                      //         downloadProgress.progress,
                                                      //     strokeWidth: 2,
                                                      //   ),
                                                      // ),
                                                      // 加载失败占位
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Column(
                                                        children: [
                                                          Image.asset(
                                                              'assets/images/error.png')
                                                        ],
                                                      ),
                                                    ))
                                                  : Image.file(
                                                      File(uri.toString()),
                                                      filterQuality:
                                                          _filterQuality,
                                                      fit: BoxFit
                                                          .cover, // 确保图片覆盖整个容器
                                                      alignment: Alignment
                                                          .center, // 确保图片居中
                                                    ),
                                            );
                                          },
                                          selectable: true,
                                          onTapLink: (text, href, title) =>
                                              launchUrl(Uri.parse(href ?? '')),

                                          data: _controller.text,
                                          // 禁用Markdown内部的滚动（避免嵌套滚动冲突）
                                          shrinkWrap: true,
                                          //physics: const NeverScrollableScrollPhysics(),
                                        ),
                                      )
                                    : Stack(
                                        children: [
                                          InAppWebView(
                                            // pullToRefreshController:
                                            // 2. 监听长按事件
                                            onLongPressHitTestResult:
                                                (controller,
                                                    hitTestResult) async {
                                              if (hitTestResult.type ==
                                                  InAppWebViewHitTestResultType
                                                      .EDIT_TEXT_TYPE) {
                                                // 获取选中的文本
                                                String? selectedText =
                                                    await controller
                                                        .getSelectedText();
                                              } else if (hitTestResult.type ==
                                                  InAppWebViewHitTestResultType
                                                      .IMAGE_TYPE) {
                                                String? src =
                                                    await hitTestResult?.extra
                                                        .toString();
                                                if (src != null) {
                                                  if (src!.startsWith(
                                                          "http://") ||
                                                      src!.startsWith(
                                                          "https://")) {}
                                                }
                                              } else if (hitTestResult.type ==
                                                  InAppWebViewHitTestResultType
                                                      .SRC_ANCHOR_TYPE) {
                                                String? src =
                                                    await hitTestResult?.extra
                                                        .toString();
                                                if (src != null) {
                                                  if (src!.startsWith(
                                                          "http://") ||
                                                      src!.startsWith(
                                                          "https://")) {}
                                                }
                                              }
                                            },
                                            // contextMenu: _contextMenu,

                                            // 初始加载的URL
                                            // 核心配置
                                            initialOptions: _webViewOptions,
                                            // WebView创建完成（获取控制器）
                                            onWebViewCreated: (controller) {
                                              // 可选：设置用户代理
                                              webController = controller;
                                              // _loadAssetsHtml();
                                              preview(_controller.text);
                                            },
                                            // 加载进度回调
                                            onProgressChanged:
                                                (controller, progress) {
                                              setState(() {
                                                if (loadProgress != 1.0) {
                                                  loadProgress = progress / 100;
                                                }
                                              });
                                            },
                                            // 页面标题变化
                                            onTitleChanged:
                                                (controller, title) {
                                              setState(() {});
                                            },
                                            onLoadStart: (controller, url) {},
                                            // 页面加载完成
                                            onLoadStop:
                                                (controller, url) async {
                                              if (loadProgress != 1.0) {
                                                loadProgress = 1.0;
                                              }
                                              // final content =
                                              //     await FileUtils.readMdFile(
                                              //         widget.filePath);

                                              // if (webController == null) return;
                                              // // 执行简单JSameDisabledCache//ameClearCache
                                              // exec(
                                              //     "javascript:vditor.clearCache();");
                                              // exec("javascript:setValue('" +
                                              //     base64Encode(utf8.encode(
                                              //         content.toString())) +
                                              //     "');");
                                              // 可选：隐藏进度条（进度设为1）
                                              // setState(() {
                                              //   _initController();

                                              //   // if (_theme) {
                                              //   //   _switchToDarkMode();
                                              //   // } else {
                                              //   //   _switchToLightMode();
                                              //   // }
                                              //   // _injectDarkModeJs();
                                              //   //
                                              // });
                                            },
                                            // 加载失败
                                            onLoadError: (controller, url, code,
                                                message) {},
                                            // URL跳转拦截（比如拦截外部链接、自定义跳转）
                                            shouldOverrideUrlLoading:
                                                (controller,
                                                    navigationAction) async {
                                              final url = navigationAction
                                                      .request.url
                                                      ?.toString() ??
                                                  "";
                                              final String decodeUrl =
                                                  Uri.decodeComponent(url);
                                              // 处理文本变化回调
                                              return NavigationActionPolicy
                                                  .CANCEL;
                                            },
                                          ),
                                          if (loadProgress != 1.0)
                                            // 占满整个父容器，居中显示圆形进度条
                                            SizedBox.expand(
                                              child: Container(
                                                height: double.infinity,
                                                // 可选：添加半透明背景，让加载框更突出
                                                color: ThemeUtil.getIsDark() ==
                                                        true
                                                    ? Colors.black
                                                    : Colors.white,
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      CircularProgressIndicator(
                                                        backgroundColor:
                                                            ThemeUtil.getIsDark() ==
                                                                    true
                                                                ? Colors.black
                                                                : Colors.white,
                                                        color: ThemeUtil
                                                                    .getIsDark() ==
                                                                true
                                                            ? Colors.white
                                                            : Colors.black,
                                                      ),
                                                      SizedBox(
                                                        height: 30,
                                                      ),
                                                      Text("加载中...")
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                          )
                        : // 编辑模式：修复TextField高度问题
                        _render != 3
                            ? SingleChildScrollView(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment
                                      .stretch, // 让TextField占满宽度
                                  children: [
                                    if (_switchValue1)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          SizedBox(width: 10),
                                          Text(
                                            textAlign: TextAlign.center,
                                            Utils.formatDateTime(),
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontFamily: 'FontAwesome'),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "|",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontFamily: 'FontAwesome'),
                                          ),
                                          SizedBox(width: 5),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${_lengthNotifier.value} ' +
                                                          'word'.tr(),
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.blue,
                                                      fontFamily:
                                                          'FontAwesome'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                        ],
                                      ),
                                    TextField(
                                      autocorrect: false,
                                      // enableSuggestions: false,
                                      controller: _controller,
                                      maxLines: null,
                                      // expands: true,
                                      onChanged: (value) => setState(() {
                                        _lengthNotifier.value = value.length;
                                      }),
                                      textAlign: TextAlign.left,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      strutStyle: const StrutStyle(
                                        fontSize: 20,
                                      ),
                                      readOnly: false,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      autofocus: false,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'markdown_hint'.tr(),
                                        contentPadding: EdgeInsets.all(10),
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ))
                            : Expanded(
                                child: Stack(children: [
                                  InAppWebView(
                                    // pullToRefreshController:
                                    // 2. 监听长按事件
                                    onLongPressHitTestResult:
                                        (controller, hitTestResult) async {
                                      if (hitTestResult.type ==
                                          InAppWebViewHitTestResultType
                                              .EDIT_TEXT_TYPE) {
                                        // 获取选中的文本
                                        String? selectedText =
                                        await controller.getSelectedText();
                                      } else if (hitTestResult.type ==
                                          InAppWebViewHitTestResultType.IMAGE_TYPE) {
                                        String? src =
                                        await hitTestResult?.extra.toString();
                                        if (src != null) {
                                          if (src!.startsWith("http://") ||
                                              src!.startsWith("https://")) {
                                            _showSaveImageConfirmDialog(src);

                                          }
                                        }
                                      } else if (hitTestResult.type ==
                                          InAppWebViewHitTestResultType
                                              .SRC_ANCHOR_TYPE) {
                                        String? src =
                                        await hitTestResult?.extra.toString();
                                        if (src != null) {
                                          if (src!.startsWith("http://") ||
                                              src!.startsWith("https://")) {
                                            _showOpenConfirmDialog(src);
                                          }
                                        }
                                      }
                                    },
                                    // contextMenu: _contextMenu,

                                    // 初始加载的URL
                                    // 核心配置
                                    initialOptions: _webViewOptions,
                                    // WebView创建完成（获取控制器）
                                    onWebViewCreated: (controller) {
                                      // 可选：设置用户代理
                                      webController = controller;
                                      _loadAssetsHtml();
                                      // preview(_controller.text);
                                    },
                                    // 加载进度回调
                                    onProgressChanged: (controller, progress) {
                                      setState(() {
                                        if (loadProgress != 1.0) {
                                          loadProgress = progress / 100;
                                        }
                                      });
                                    },
                                    // 页面标题变化
                                    onTitleChanged: (controller, title) {
                                      setState(() {});
                                    },
                                    onLoadStart: (controller, url) {},
                                    // 页面加载完成
                                    onLoadStop: (controller, url) async {
                                      final content =
                                          await FileUtils.readMdFile(
                                              widget.filePath);
                                      if (webController == null) return;
                                      // 执行简单JSameDisabledCache//ameClearCache

                                      exec("javascript:vditor.clearCache();");
                                      exec("javascript:setValue('" +
                                          base64Encode(
                                              utf8.encode(content.toString())) +
                                          "');");
                                      if (loadProgress != 1.0) {
                                        loadProgress = 1.0;
                                      }
                                      // 可选：隐藏进度条（进度设为1）
                                      // setState(() {
                                      //   _initController();

                                      //   // if (_theme) {
                                      //   //   _switchToDarkMode();
                                      //   // } else {
                                      //   //   _switchToLightMode();
                                      //   // }
                                      //   // _injectDarkModeJs();
                                      //   //
                                      // });
                                    },
                                    // 加载失败
                                    onLoadError:
                                        (controller, url, code, message) {},
                                    // URL跳转拦截（比如拦截外部链接、自定义跳转）
                                    shouldOverrideUrlLoading:
                                        (controller, navigationAction) async {
                                      final url = navigationAction.request.url
                                              ?.toString() ??
                                          "";
                                      final String decodeUrl =
                                          Uri.decodeComponent(url);
                                      return NavigationActionPolicy.CANCEL;
                                      // 处理文本变化回调
                                    },
                                  ),
                                  if (loadProgress != 1.0)
                                    // 占满整个父容器，居中显示圆形进度条
                                    SizedBox.expand(
                                      child: Container(
                                        height: double.infinity,
                                        // 可选：添加半透明背景，让加载框更突出
                                        color: ThemeUtil.getIsDark() == true
                                            ? Colors.black
                                            : Colors.white,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                backgroundColor:
                                                    ThemeUtil.getIsDark() ==
                                                            true
                                                        ? Colors.black
                                                        : Colors.white,
                                                color: ThemeUtil.getIsDark() ==
                                                        true
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              Text("加载中...")
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ]),
                              ),
                  ),

                  // Column(
                  //     mainAxisAlignment: MainAxisAlignment.center,
                  //     crossAxisAlignment: CrossAxisAlignment.center,
                  //     children: [
                  //       // Row(
                  //       //   verticalDirection: VerticalDirection.down,
                  //       //   crossAxisAlignment: CrossAxisAlignment.center,
                  //       //   mainAxisAlignment: MainAxisAlignment.end,
                  //       //   children: [
                  //       //     Text(
                  //       //       "已输入：${_lengthNotifier.value} 字",
                  //       //       style: const TextStyle(fontSize: 14),
                  //       //     ),
                  //       //     const SizedBox(width: 20),
                  //       //   ],
                  //       // ),

                  //     ],
                  //   )

                  if (_isToolBarVisible)
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.start, // 与原布局对齐方式保持一致
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // 与原布局对齐方式保持一致
                      children: [
                        // 第一部分：固定在最左侧的 IconButton（不会滚动）
                        IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          onPressed: () => setState(() {
                            _showChatDialog();
                          }),
                          tooltip: 'left_align'.tr(),
                          style: ButtonStyle(
                            // 圆形形状（关键：CircleBorder 实现纯圆形）
                            shape:
                                MaterialStateProperty.all(const CircleBorder()),
                            // 边框样式：颜色+宽度（可自定义）
                            side: MaterialStateProperty.all(
                              const BorderSide(
                                color: Colors.blue, // 边框颜色
                                width: 1.0, // 边框宽度
                              ),
                            ),
                            // 可选：调整按钮大小（按需）

                            padding: MaterialStateProperty.all(
                                const EdgeInsets.all(8)),
                          ),
                        ),
                        if (_render != 3)
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_rounded),
                            onPressed: () => setState(() {
                              // _loadAssetsHtml(_controller.text);
                              // _view(_controller.text);
                              // preview(_controller.text);
                              _isPreview = !_isPreview;
                              _isEdit = !_isEdit;
                              _isToolBarVisible = !_isToolBarVisible;
                            }),
                            tooltip: 'preview'.tr(),
                            style: ButtonStyle(
                              // 圆形形状（关键：CircleBorder 实现纯圆形）
                              shape: MaterialStateProperty.all(
                                  const CircleBorder()),
                              // 边框样式：颜色+宽度（可自定义）
                              side: MaterialStateProperty.all(
                                const BorderSide(
                                  color: Colors.red, // 边框颜色
                                  width: 1.0, // 边框宽度
                                ),
                              ),
                              // 可选：调整按钮大小（按需）

                              padding: MaterialStateProperty.all(
                                  const EdgeInsets.all(8)),
                            ),
                          ),

                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: () => _saveContent(),
                          tooltip: 'save'.tr(),
                          style: ButtonStyle(
                            // 圆形形状（关键：CircleBorder 实现纯圆形）
                            shape:
                                MaterialStateProperty.all(const CircleBorder()),
                            // 边框样式：颜色+宽度（可自定义）
                            side: MaterialStateProperty.all(
                              const BorderSide(
                                color: Colors.green, // 边框颜色
                                width: 1.0, // 边框宽度
                              ),
                            ),
                            // 可选：调整按钮大小（按需）

                            padding: MaterialStateProperty.all(
                                const EdgeInsets.all(8)),
                          ),
                        ),

                        // Padding(
                        //           padding: const EdgeInsets.only(right: 0),
                        //           child: IconButton(
                        //             icon: _isSaving
                        //                 ? const SizedBox(
                        //                     width: 24,
                        //                     height: 24,
                        //                     child: CircularProgressIndicator(color: Colors.white),
                        //                   )
                        //                 : const Icon(Icons.save),
                        //             onPressed: _saveContent,
                        //             tooltip: 'save'.tr(),
                        //           ),
                        //         ),

                        // 第二部分：可滚动的按钮区域（包含剩余所有按钮）

                        Expanded(
                          // 加 Expanded 防止滚动区域宽度溢出（根据需求可选）
                          child: Scrollbar(
                            thickness: 0, // 隐藏滚动条（保持原有逻辑）
                            scrollbarOrientation: ScrollbarOrientation.left,
                            child: SingleChildScrollView(
                              reverse: true,
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.horizontal, // 水平滚动
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // 以下是需要滚动的所有按钮（原列表中除第一个外的剩余按钮）

                                  IconButton(
                                    icon: const Icon(Icons.h_mobiledata),
                                    onPressed: () =>
                                        _wrapMarkdown(prefix: '#', suffix: ''),
                                    tooltip: 'title'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_bold),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '**', suffix: '**'),
                                    tooltip: 'bold'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_italic),
                                    onPressed: () =>
                                        _wrapMarkdown(prefix: '*', suffix: '*'),
                                    tooltip: 'italic'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.format_list_bulleted),
                                    onPressed: () =>
                                        _wrapMarkdown(prefix: '- ', suffix: ''),
                                    tooltip: 'unordered_list'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_quote),
                                    onPressed: () =>
                                        _wrapMarkdown(prefix: '> ', suffix: ''),
                                    tooltip: 'quote'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.format_list_numbered),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '1. ', suffix: ''),
                                    tooltip: 'ordered_list'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.format_strikethrough),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '~~', suffix: '~~'),
                                    tooltip: 'strikethrough'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.code),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '```', suffix: '```'),
                                    tooltip: 'code'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_box),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '- [x] ', suffix: ''),
                                    tooltip: 'checkbox',
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.check_box_outline_blank),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '- [ ] ', suffix: ''),
                                    tooltip: 'checkbox',
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.image),
                                    onPressed: () =>
                                        _showImageOptionDialog(), // 点击触发弹窗,
                                    tooltip: 'image'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.link),
                                    onPressed: () => _wrapMarkdown(
                                        prefix: '[', suffix: '](url)'),
                                    tooltip: 'insert_link'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.rocket_launch_rounded),
                                    onPressed: () => _showModelOptionDialog(),
                                    tooltip: 'insert_link'.tr(),
                                    style: ButtonStyle(
                                      // 圆形形状（关键：CircleBorder 实现纯圆形）
                                      shape: MaterialStateProperty.all(
                                          const CircleBorder()),
                                      // 边框样式：颜色+宽度（可自定义）
                                      side: MaterialStateProperty.all(
                                        const BorderSide(
                                          color: Colors.grey, // 边框颜色
                                          width: 1.0, // 边框宽度
                                        ),
                                      ),
                                      // 可选：调整按钮大小（按需）

                                      padding: MaterialStateProperty.all(
                                          const EdgeInsets.all(8)),
                                    ),
                                  ),
                                  //rocket_launch_rounded
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: 10),
                ],
              ),
      ),
    );
  }

  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
  // 原有方法：获取修改时间（保留）
  Future<String> _getModifiedTime(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      return _dateFormatter.format(stat.modified);
    } catch (e) {
      return 'unknown_time'.tr();
    }
  }
  // 原有方法：单个删除（保留）
  Future<void> _showOpenConfirmDialog(String src) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("open_browser".tr()),
        content: Text("open_browser_hint".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              launchUrl(Uri.parse(src));
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  // 原有方法：单个删除（保留）
  Future<void> _showSaveImageConfirmDialog(String src) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("save_image".tr()),
        content: Text("save_image_hint".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FileUtils.saveNetworkImageToGallery(src);
                Utils.showToast(context, "save_success".tr());
              } catch (e) {
                if (mounted) {
                  Utils.showToast(context, 'delete_failed'.tr());
                }
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
  List<FileSystemEntity> fileList = [];
  void _showModelOptionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'rich_insert_model'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4, // 最多占屏幕40%高度
              child: ListView.builder(
                shrinkWrap: true,
                // 关键修改3：移除NeverScrollableScrollPhysics，恢复列表滚动能力
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: fileList.length,
                itemBuilder: (context, index) =>
                    _buildListItem(fileList[index]),
              ),
            ),
            // 取消按钮
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    child: Center(
                        child: Text('cancel'.tr(),
                            style: TextStyle(color: Colors.red)))),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void insertAtCursor(String textToInsert) {
    final text = _controller.text;
    final selection = _controller.selection;
    // 光标位置，无选中时 start == end
    final cursorPos = selection.start;

    // 插入逻辑
    final newText =
        text.substring(0, cursorPos) + textToInsert + text.substring(cursorPos);
    // 更新文本和光标位置（光标移到插入内容末尾）
    _controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: cursorPos + textToInsert.length),
    );
  }

  void _onItemTap(FileSystemEntity entity) async {
    if (entity is File && path.extension(entity.path) == '.mgtx') {
      final fileName = path.basenameWithoutExtension(entity.path);
      // _showDialog(entity.path);
    } else if (entity is File && path.extension(entity.path) == '.mmd') {
      final fileName = path.basenameWithoutExtension(entity.path);
      final content = await FileUtils.readMdFile(entity.path);
      setState(() {
        Utils.showToast(context, "insert_success".tr());
      });
      if (_render == 3) {
        exec("javascript:insertValue('" +
            base64Encode(utf8.encode(content.toString())) +
            "');");
        return;
      } else {
        insertAtCursor(content);
      }

      // _showMdDialog(entity.path);
    }
  }

  Future<void> _loadFiles(String type) async {
    final appDir = await FileUtils.getAppDocDir();
    final folderPath = path.join(appDir.path, type);
    if (!await Directory(folderPath).exists()) {
      await Directory(folderPath).create(recursive: true);
    }
    final entities = await Directory(folderPath).list().toList();
    // 排序：文件夹优先，按名称升序
    entities.sort((a, b) {
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;
      return a.path.compareTo(b.path);
    });
    setState(() {
      if (type == "md_model") {
        fileList = entities;
      }
    });
  }

  // 新增：构建列表视图项（带内容预览）
  Widget _buildListItem(FileSystemEntity entity) {
    final name = path.basename(entity.path).split(".").first;
    String e = path.extension(entity.path);
    final isDir = entity is Directory;
    // final isSelected = _selectedIds.contains(entity);
    return FutureBuilder(
      future: Future.wait([_getModifiedTime(entity)]),
      initialData: ['loading'.tr(), ''],
      builder: (context, snapshot) {
        final modifyTime = snapshot.data?[0] ?? 'unknown_time'.tr();
        final previewContent = isDir ? 'folder'.tr() : '';
        //(snapshot.data?[0] ?? '')
        return Stack(
          children: [
            ListTile(
              style: ListTileStyle.list,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDir ? Colors.blue[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  size: 28,
                  isDir
                      ? Icons.folder
                      : e == ".md"
                          ? Icons.article_outlined
                          : Icons.article_outlined,
                  color: isDir ? Colors.blue[700] : Colors.grey[600],
                ),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${'modify_time'.tr()}${modifyTime}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (previewContent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        previewContent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    )
                ],
              ),
              onTap: () {
                _onItemTap(entity);
                Navigator.pop(context);
                // if (_isEditMode) {
                //   //_toggleItemSelection(entity);
                // } else {
                //   _onItemTap(entity);
                // }
              },
              // onLongPress: () => _showOptionDialog(entity),
            ),
          ],
        );
      },
    );
  }
}
