import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/main.dart';
import 'package:editor/page/backups/webdav.dart';
import 'package:editor/page/person/github_api.dart';
import 'package:editor/provider.dart';
import 'package:editor/rich/api.dart';
import 'package:editor/theme.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/widget/dialog_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http_server/http_server.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

import 'package:image/image.dart' as img; // 新增：图片压缩

class EditPage extends StatefulWidget {
  final String filePath;
  final String? fileName;

  const EditPage({
    super.key,
    required this.filePath,
    this.fileName,
  });
  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController _githubRepoController = TextEditingController();

  late TextEditingController _githubBranchController = TextEditingController();
  Map<String, dynamic> gitConfig = Utils.getGitConfig();
  // 核心控制器：所有WebView操作的入口
  InAppWebViewController? webController;
  // 加载进度
  double loadProgress = 0.0;
  bool _isMenu = false;
  String _selectText = "";
  bool _theme = false;
  // 注入 JavaScript 监听文本选择
  void _injectSelectionListener() async {
    await webController?.evaluateJavascript(source: """
    (function() {
      let lastSelection = '';
      
      // 监听选择变化
      document.addEventListener('selectionchange', function() {
        setTimeout(function() {
          const selection = window.getSelection();
          const text = selection.toString().trim();
          
          // 有选中文本
          if (text.length > 0) {
            lastSelection = text;
            const range = selection.getRangeAt(0);
            const rect = range.getBoundingClientRect();
            
            window.flutter_inappwebview.callHandler('onTextSelected', {
              text: text,
              x: rect.left + rect.width / 2,
              y: rect.top
            });
          } 
          // 取消选择
          else if (lastSelection.length > 0) {
            lastSelection = '';
            window.flutter_inappwebview.callHandler('onSelectionCleared');
          }
        }, 100);
      });
      
      // 监听点击事件（取消选择）
      document.addEventListener('click', function(e) {
        setTimeout(function() {
          const selection = window.getSelection();
          if (selection.toString().trim().length === 0 && lastSelection.length > 0) {
            lastSelection = '';
            window.flutter_inappwebview.callHandler('onSelectionCleared');
          }
        }, 50);
      });
      
      // 监听触摸事件（取消选择）
      document.addEventListener('touchstart', function(e) {
        setTimeout(function() {
          const selection = window.getSelection();
          if (selection.toString().trim().length === 0 && lastSelection.length > 0) {
            lastSelection = '';
            window.flutter_inappwebview.callHandler('onSelectionCleared');
          }
        }, 50);
      });
    })();
  """);

    // await webController?.evaluateJavascript(source: """
    //   (function() {
    //     let selectionTimeout;
    //     document.addEventListener('selectionchange', function() {
    //       clearTimeout(selectionTimeout);
    //       selectionTimeout = setTimeout(function() {
    //         const selection = window.getSelection();
    //         const selectedText = selection.toString().trim();
    //         if (selectedText.length > 0) {
    //           const range = selection.getRangeAt(0);
    //           const rect = range.getBoundingClientRect();
    //           window.flutter_inappwebview.callHandler('onTextSelected', {
    //             text: selectedText,
    //             x: rect.left + rect.width / 2,
    //             y: rect.top
    //           });
    //         }
    //       }, 100);
    //     });
    //     let longPressTimer;
    //     document.addEventListener('touchstart', function(e) {
    //       longPressTimer = setTimeout(function() {
    //         const selection = window.getSelection();
    //         if (selection.toString().trim().length > 0) {
    //           const range = selection.getRangeAt(0);
    //           const rect = range.getBoundingClientRect();
    //           window.flutter_inappwebview.callHandler('onLongPress', {
    //             text: selection.toString().trim(),
    //             x: rect.left + rect.width / 2,
    //             y: rect.top
    //           });
    //         }
    //       }, 500);
    //     });

    //     document.addEventListener('touchend', function() {
    //       clearTimeout(longPressTimer);
    //     });
    //   })();
    // """);

    // 添加 Handler 接收 JavaScript 消息
    webController?.addJavaScriptHandler(
      handlerName: 'onTextSelected',
      callback: (args) {
        final data = args[0];
        // 显示自定义菜单
        _selectText = data['text'];
        // Utils.showToast(context,
        //     '选中文本: ${data['text']}' + '位置: x=${data['x']}, y=${data['y']}');
        try {
          setState(() {
            _isMenu = true;
          });
        } catch (e) {
          //debugPrint("牛逼" + e.toString());
          //Utils.showToast(context, e.toString());
        }
      },
    );
    // 监听取消选择
    webController?.addJavaScriptHandler(
      handlerName: 'onSelectionCleared',
      callback: (args) {
        setState(() {
          _isMenu = false;
        });
      },
    );
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

  Future<void> _showTocConfirmDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("create_otc".tr()),
        content: Text("create_otc_hint".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              _jsApi.setGenerateToc();
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
        title: Text("save_model".tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "save_model_hint".tr()),
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
                    widget.filePath,
                    controller.text,
                    Uri.decodeComponent(
                        await _jsApi.getData("javascript:Rich.getHtmlData()")));
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

  // 注入JS强制深色模式（兜底方案）
  // 切换为浅色（白天）模式
  Future<void> _switchToLightMode() async {
    if (webController == null) return;

    // 2. 注入JS清除深色样式，恢复网页默认浅色
    await webController!.evaluateJavascript(source: """
      // 移除深色模式标识
      document.documentElement.removeAttribute('data-theme');
      // 删除之前注入的深色样式
      const injectedStyles = document.querySelectorAll('style[data-dark-mode]');
      injectedStyles.forEach(style => style.remove());
      // 恢复全局默认样式
      const resetStyle = document.createElement('style');
      resetStyle.innerHTML = `
        * {
          color-scheme: light !important;
          background-color: initial !important; // 恢复初始值
          color: initial !important;
          border-color: initial !important;
        }
        a { color: initial !important; }
        
      `;
      resetStyle.setAttribute('data-light-mode', 'true');
      document.head.appendChild(resetStyle);
  
      window.matchMedia('(prefers-color-scheme: light)').dispatchEvent(new Event('change'));
    """);
  }

  // 切换为深色模式（备用，方便对比测试）
  Future<void> _switchToDarkMode() async {
    if (webController == null) return;

    // await webController!.setOptions(
    //   options: InAppWebViewGroupOptions(
    //     android: AndroidInAppWebViewOptions(
    //       forceDark: AndroidForceDark.FORCE_DARK_ON,
    //     ),
    //   ),
    // );

    await webController!.evaluateJavascript(source: """
      document.documentElement.setAttribute('data-theme', 'dark');
      const resetStyles = document.querySelectorAll('style[data-light-mode]');
      resetStyles.forEach(style => style.remove());
      const darkStyle = document.createElement('style');
      darkStyle.setAttribute('data-dark-mode', 'true');
      darkStyle.innerHTML = `
        * {
          color-scheme: dark !important;
          background-color: #121212 !important;
          color: #ffffff !important;
          border-color: #333 !important;
        }
        a { color: #8ab4f8 !important; }
        input, textarea, [contenteditable="true"] {
        caret-color: #8ab4f8 !important; 
      }
      
      `;
      document.head.appendChild(darkStyle);
      window.matchMedia('(prefers-color-scheme: dark)').dispatchEvent(new Event('change'));
    """);
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

  HttpServer? _localServer; // 本地HTTP服务器
  int _serverPort = 8080; // 自定义端口（可修改）
  late JsApi _jsApi;
  String html = "";
  final ImagePicker _imagePicker = ImagePicker();
  static const String _callbackScheme = "re-callback://";
  static const String _stateScheme = "re-state://";
  static const String _todoScheme = "re-undo-redo://";
  static const String _saveScheme = "re-save-image://";
  static const String _stateHtmlScheme = "re-state-html://";
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isPreview = false; // 是否预览模式
  bool _isToolBarVisible = true;
  // 关键：存储每个图标的选中状态，key为IconData，value为是否选中
  final Map<IconData, bool> _iconSelectedStates = {};
  final Set<FormatType> _activeFormats = {};
  // final String _stateScheme = "state://"; // 你的状态回调scheme
  @override
  void dispose() {
    // 页面销毁时关闭本地服务器，避免资源泄漏
    _disposeWebViewResources();
    super.dispose();
  }

  // 封装WebView资源释放逻辑
  Future<void> _disposeWebViewResources() async {
    if (webController == null) return;
    try {
      await webController?.removeAllUserScripts();
      // 2. 停止所有加载中的请求（释放网络资源）
      await webController?.stopLoading();
      // 3. 手动销毁原生WebView（6.1.5版本核心API）
      // await webController?.destroy();
      // 4. 清空控制器引用，触发GC回收
      webController = null;
    } catch (e) {
      // debugPrint("释放WebView资源时出错：$e");
    }
  }

  // ========== 基础功能封装 ==========
  /// 1. 执行JS代码（Flutter调用JS）
  Future<void> _executeJS(
      InAppWebViewController webController, String js) async {
    if (webController == null) return;
    // 执行简单JS
    final result = await webController?.evaluateJavascript(
      source: js,
    );
    // 接收JS返回值
    if (result != null) {}
  }

  /// 2. 加载本地HTML文件（含本地图片）
  Future<void> _loadAssetsHtml() async {
    if (webController == null) return;
    if (_theme) {
      await webController?.loadFile(
          assetFilePath: 'assets/html/editor-dark.html');
    } else {
      await webController?.loadFile(assetFilePath: 'assets/html/editor.html');
    }

    setState(() {});
  }

  void _toggleIconState(IconData icon) {
    final FormatType? type = FormatType.fromIcon(icon);
    if (type != null) {
      setState(() {
        _activeFormats.contains(type)
            ? _activeFormats.remove(type)
            : _activeFormats.add(type);
      });
    }
  }

  void setSelection() async {
    await webController?.evaluateJavascript(source: """
  const selection = window.getSelection();
  if (selection.rangeCount > 0) {
    const originalRange = selection.getRangeAt(0);
    const endContainer = originalRange.endContainer; 
    const endOffset = originalRange.endOffset;    
    selection.removeAllRanges();
    const newRange = document.createRange();
    newRange.setStart(endContainer, endOffset);
    newRange.setEnd(endContainer, endOffset);
    selection.addRange(newRange);
  } else {
    selection.removeAllRanges();
  }
""");
  }

  // 检查按钮是否处于选中状态
  bool _isIconActive(IconData icon) {
    final FormatType? type = FormatType.fromIcon(icon);
    return type != null && _activeFormats.contains(type);
  }

// 新增：图片压缩方法，解决大图片内存问题
  Future<Uint8List> _compressImage(Uint8List imageBytes,
      {int quality = 60, int maxWidth = 1080}) async {
    try {
      final img.Image image = img.decodeImage(imageBytes)!;
      final int width = image.width;
      final int height = image.height;

      // 按比例缩放图片
      if (width > maxWidth) {
        final double ratio = maxWidth / width;
        final int newHeight = (height * ratio).toInt();
        final img.Image resizedImage =
            img.copyResize(image, width: maxWidth, height: newHeight);
        return img.encodeJpg(resizedImage, quality: quality);
      }
      return img.encodeJpg(image, quality: quality);
    } catch (e) {
      // debugPrint("图片压缩失败：$e");
      return imageBytes; // 压缩失败返回原数据
    }
  }

// 参考官方示例：保存为 Markdown
  Future<void> _saveContent({bool value = true}) async {
    if (_isSaving) return;
    try {
      bool isSuccess = await FileUtils.saveHtmlFile(
          widget.filePath,
          Uri.decodeComponent(
              await _jsApi.getData("javascript:Rich.getHtmlData()")));
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
    // 自动备份
    if (Utils.getBackupsConfig()['is_auto']) {
      final file = File(widget.filePath);
      bool upload = await Webdav.uploadFile(file);
    }
  }

  // 参考官方示例：初始化编辑器控制器
  Future<void> _initController() async {
    _isLoading = true;
    try {
      final content = await FileUtils.readHtmlFile(widget.filePath);
      setState(() {
        // Utils.showToast(context, "" + content);
        if (!content.isEmpty || content.length > 0) {
          _isPreview = true;
          _jsApi.setInputEnabled(false);
          _isLoading = true;
          _isToolBarVisible = false;
        }
        _executeJS(
            webController!,
            "javascript:Rich.setHtml('" +
                base64Encode(utf8.encode(content.toString())) +
                "');");
      });
    } catch (e) {}
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
      if (type == "gtx_model") {
        fileList = entities;
      }
    });
  }

  void theme() {
    _theme = ThemeUtil.getIsDark();
    // Utils.showToast(context, "is" + _theme.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadFiles("gtx_model");
    _isLoading = true;
    ThemeProvider update = Provider.of<ThemeProvider>(context, listen: false);
    theme();
    update.addListener(theme);
    // final themeProvider = Provider.of<ThemeProvider>(context);
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // themeProvider.setThemeMode(ThemeMode.dark);
    // 等待当前帧刷新完成（状态已更新）
    // 等待初始化完成后再获取
    // Consumer<ThemeProvider>(
    //   builder: (context, provider, child) {
    //     return Text(
    //       "当前 isDarkMode：${provider.isDarkMode}",
    //       style: const TextStyle(fontSize: 20),
    //     );
    //   },
    // );
  }

  // 替换选中的文本为新内容
  Future<void> _replaceSelectedText(String? newText) async {
    // 转义特殊字符
    final escapedText = newText!
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '<br>');
    await webController?.evaluateJavascript(source: """
      (function() {
        const selection = window.getSelection();
        if (selection.rangeCount > 0) {
          const range = selection.getRangeAt(0);
          range.deleteContents();
          const textNode = document.createTextNode('$escapedText');
          range.insertNode(textNode);
          range.setStartAfter(textNode);
          range.collapse(true);
          selection.removeAllRanges();
          selection.addRange(range);
        }
      })();
    """);
  }

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
                  //  Utils.getGitConfig()['repo'],
                  //       Utils.getGitConfig()['branch'],
                  //        Utils.getGitConfig()['message']
                Utils.saveGitConfig(
                  isDialog:Utils.getGitConfig()['dialog'],
                  message: Utils.getGitConfig()['message'],
                  repo: repo,
                  branch: branch,
                  imagePath: Utils.getGitConfig()['image'],
                );
                DialogWidget.show(context: context);
                bool isSuccess = await _publishContent(
                    repo, branch,  Utils.getGitConfig()['message']);
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
              setState(() {});
            }
          }
        } catch (e) {
          Utils.showToast(context, 'publish_failed'.tr());
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
          setState(() {});
        }
      }
    } catch (e) {
      Utils.showToast(context, 'publish_failed'.tr());
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // 自定义退出逻辑：先隐藏WebView，再执行退出
        setState(() {
          // 设置状态使WebView隐藏
          //  _cancelSaveTimer();
          _isLoading = false;
        });
        _saveContent(value: false);
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
      child: Scaffold(
        appBar: AppBar(
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: IconButton(
                icon:
                    _isPreview ? Icon(Icons.edit) : Icon(Icons.remove_red_eye),
                onPressed: () {
                  if (_isPreview) {
                    setState(() {
                      _isPreview = false;
                      _isToolBarVisible = true;
                      _jsApi.setInputEnabled(true);
                    });
                  } else {
                    setState(() {
                      _jsApi.setInputEnabled(false);
                      _isPreview = true;
                      _isToolBarVisible = false;
                    });
                  }
                },
                tooltip: 'edit'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: IconButton(
                icon: !_isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.black),
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
                         Utils.getGitConfig()['message'],);
                    if (isSuccess) {
                      DialogWidget.dismiss(context);
                    } else {
                      DialogWidget.dismiss(context);
                    }
                  }
                },
                tooltip: 'publish',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: IconButton(
                icon: Icon(Icons.move_to_inbox_outlined),
                onPressed: () {
                  _saveContent();
                  _showSaveModelConfirmDialog();
                },
                tooltip: 'save'.tr(),
              ),
            ),
          ],
          title: Text(widget.fileName!),
        ),
        body: Column(
          children: [
            // 关键修改：将 Column 改为 Stack 实现层叠覆盖
            Expanded(
              child: Stack(
                children: [
                  // 1. WebView 作为底层组件（始终显示）
                  Container(
                    width: double.infinity,
                    child: !_isLoading
                        ? Center(
                            child: Column(
                            children: [
                              CircularProgressIndicator(
                                backgroundColor: ThemeUtil.getIsDark() == true
                                    ? Colors.white
                                    : Colors.black,
                                color: ThemeUtil.getIsDark() == true
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              Text("加载中...")
                            ],
                          ))
                        : InAppWebView(
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
                                    _jsApi.clearFocusEditor();
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
                              webController = controller;
                              setState(() {
                                _jsApi = JsApi(webController!);
                                _loadAssetsHtml();
                              });

                              // 可选：设置用户代理
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
                              // 可选：隐藏进度条（进度设为1）
                              setState(() {
                                _initController();
                                if (loadProgress != 1.0) {
                                  loadProgress = 1.0;
                                }
                                _injectSelectionListener();
                                // if (_theme) {
                                //   _switchToDarkMode();
                                // } else {
                                //   _switchToLightMode();
                                // }
                                // _injectDarkModeJs();
                                //
                              });
                            },
                            // 加载失败
                            onLoadError: (controller, url, code, message) {},
                            // URL跳转拦截（比如拦截外部链接、自定义跳转）
                            shouldOverrideUrlLoading:
                                (controller, navigationAction) async {
                              final url =
                                  navigationAction.request.url?.toString() ??
                                      "";
                              final String decodeUrl = Uri.decodeComponent(url);
                              // 处理文本变化回调
                              if (url.contains(_callbackScheme)) {
                                html =
                                    decodeUrl.replaceFirst(_callbackScheme, "");
                                return NavigationActionPolicy.CANCEL;
                              }
                              //处理格式状态回调
                              else if (url.contains(_stateScheme)) {
                                // final String decodeUrl = Uri.decodeFull(url);
                                final String state = url
                                    .replaceFirst(_stateScheme, "")
                                    .toUpperCase();
                                setState(() {
                                  // 清空原有状态
                                  _activeFormats.clear();
                                  // 分割状态字符串（假设状态用逗号/空格分隔，如"BOLD,ITALIC"）
                                  final List<String> stateItems =
                                      state.split(RegExp(r'[, ]+'));
                                  // 匹配并添加激活的格式
                                  for (var item in stateItems) {
                                    final FormatType? type =
                                        FormatType.fromName(item);
                                    if (type != null) {
                                      _activeFormats.add(type);
                                    }
                                  }
                                });
                                return NavigationActionPolicy.CANCEL;
                              } else if (url.contains(_todoScheme)) {
                                return NavigationActionPolicy.CANCEL;
                              } else if (url.contains(_saveScheme)) {
                                final String state = url
                                    .replaceFirst(_saveScheme, "")
                                    .toString();
                                // Utils.showToast(context, "保存成功" + state);
                                // await FileUtils.saveNetworkImageToGallery(state);
                                //Utils.showToast(context, "保存成功");
                                return NavigationActionPolicy.CANCEL;
                              } else if (url.contains(_stateHtmlScheme)) {
                                SystemChannels.textInput
                                    .invokeMethod('TextInput.hide');
                                return NavigationActionPolicy.CANCEL;
                              } else {
                                return NavigationActionPolicy.CANCEL;
                              }
                            },
                          ),
                    // : WebViewWidget(controller: _webViewController),
                  ),

                  // 2. 加载进度条（条件显示，覆盖在WebView顶层）
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                backgroundColor: ThemeUtil.getIsDark() == true
                                    ? Colors.black
                                    : Colors.white,
                                color: ThemeUtil.getIsDark() == true
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
            ),
            // if (loadProgress != 1.0)
            //   LinearProgressIndicator(
            //     color: Colors.black,
            //     backgroundColor: Colors.white,
            //     minHeight: 1,
            //     value: loadProgress, // 设置进度值
            //   ),
            //if (loadProgress != 1.0)
            // Expanded(
            //     flex: 1,
            //     child: Container(
            //       height: double.infinity,
            //       child: const Center(
            //         child: const CircularProgressIndicator(),
            //       ),
            //     )),
            // Expanded(
            //   flex: 1,
            //   child: Container(
            //     width: double.infinity,

            //     child: !_isLoading
            //         ? Center(child: const CircularProgressIndicator())
            //         : InAppWebView(
            //             // pullToRefreshController:
            //             // 2. 监听长按事件
            //             onLongPressHitTestResult:
            //                 (controller, hitTestResult) async {
            //               if (hitTestResult.type ==
            //                   InAppWebViewHitTestResultType.EDIT_TEXT_TYPE) {
            //                 // 获取选中的文本
            //                 String? selectedText =
            //                     await controller.getSelectedText();
            //               } else if (hitTestResult.type ==
            //                   InAppWebViewHitTestResultType.IMAGE_TYPE) {
            //                 String? src = await hitTestResult?.extra.toString();
            //                 if (src != null) {
            //                   if (src!.startsWith("http://") ||
            //                       src!.startsWith("https://")) {
            //                     _showSaveImageConfirmDialog(src);
            //                     _jsApi.clearFocusEditor();
            //                   }
            //                 }
            //               } else if (hitTestResult.type ==
            //                   InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE) {
            //                 String? src = await hitTestResult?.extra.toString();
            //                 if (src != null) {
            //                   if (src!.startsWith("http://") ||
            //                       src!.startsWith("https://")) {
            //                     _showOpenConfirmDialog(src);
            //                   }
            //                 }
            //               }
            //             },
            //             // contextMenu: _contextMenu,

            //             // 初始加载的URL
            //             // 核心配置
            //             initialOptions: _webViewOptions,
            //             // WebView创建完成（获取控制器）
            //             onWebViewCreated: (controller) {
            //               webController = controller;
            //               setState(() {
            //                 _jsApi = JsApi(webController!);

            //                 _loadAssetsHtml();
            //               });

            //               // 可选：设置用户代理
            //             },
            //             // 加载进度回调
            //             onProgressChanged: (controller, progress) {
            //               setState(() {
            //                 loadProgress = progress / 100;
            //               });
            //             },
            //             // 页面标题变化
            //             onTitleChanged: (controller, title) {
            //               setState(() {});
            //             },
            //             onLoadStart: (controller, url) {},
            //             // 页面加载完成
            //             onLoadStop: (controller, url) async {
            //               // 可选：隐藏进度条（进度设为1）
            //               setState(() {
            //                 _initController();
            //                 loadProgress = 1.0;
            //                 _injectSelectionListener();
            //                 // if (_theme) {
            //                 //   _switchToDarkMode();
            //                 // } else {
            //                 //   _switchToLightMode();
            //                 // }
            //                 // _injectDarkModeJs();
            //                 //
            //               });
            //             },
            //             // 加载失败
            //             onLoadError: (controller, url, code, message) {},
            //             // URL跳转拦截（比如拦截外部链接、自定义跳转）
            //             shouldOverrideUrlLoading:
            //                 (controller, navigationAction) async {
            //               final url =
            //                   navigationAction.request.url?.toString() ?? "";
            //               final String decodeUrl = Uri.decodeComponent(url);
            //               // 处理文本变化回调
            //               if (url.contains(_callbackScheme)) {
            //                 html = decodeUrl.replaceFirst(_callbackScheme, "");
            //                 return NavigationActionPolicy.CANCEL;
            //               }
            //               //处理格式状态回调
            //               else if (url.contains(_stateScheme)) {
            //                 // final String decodeUrl = Uri.decodeFull(url);
            //                 final String state = url
            //                     .replaceFirst(_stateScheme, "")
            //                     .toUpperCase();
            //                 setState(() {
            //                   // 清空原有状态
            //                   _activeFormats.clear();
            //                   // 分割状态字符串（假设状态用逗号/空格分隔，如"BOLD,ITALIC"）
            //                   final List<String> stateItems =
            //                       state.split(RegExp(r'[, ]+'));
            //                   // 匹配并添加激活的格式
            //                   for (var item in stateItems) {
            //                     final FormatType? type =
            //                         FormatType.fromName(item);
            //                     if (type != null) {
            //                       _activeFormats.add(type);
            //                     }
            //                   }
            //                 });
            //                 return NavigationActionPolicy.CANCEL;
            //               } else if (url.contains(_todoScheme)) {
            //                 return NavigationActionPolicy.CANCEL;
            //               } else if (url.contains(_saveScheme)) {
            //                 final String state =
            //                     url.replaceFirst(_saveScheme, "").toString();
            //                 // Utils.showToast(context, "保存成功" + state);
            //                 // await FileUtils.saveNetworkImageToGallery(state);
            //                 //Utils.showToast(context, "保存成功");
            //                 return NavigationActionPolicy.CANCEL;
            //               } else if (url.contains(_stateHtmlScheme)) {
            //                 SystemChannels.textInput
            //                     .invokeMethod('TextInput.hide');
            //                 return NavigationActionPolicy.CANCEL;
            //               } else {
            //                 return NavigationActionPolicy.CANCEL;
            //               }
            //             }),
            //     // : WebViewWidget(controller: _webViewController),
            //   ),
            // ),
            AnimatedSwitcher(
              // 动画时长（可根据需求调整）
              duration: const Duration(milliseconds: 300),
              // 动画曲线（缓入缓出，更自然）
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  // 偏移量：从上方（Offset(0, -1)）滑到原位置（Offset(0, 0)）
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2), // 初始位置：上方完全隐藏
                    end: const Offset(0, 0), // 结束位置：正常显示
                  ).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.decelerate),
                  ),
                  child: child,
                );
              },
              // 满足条件时显示 Container，否则显示空组件
              child: _isMenu && !_isPreview
                  ? Container(
                      width: double.infinity,
                      height: 50,
                      // color: Colors.white,
                      child: Scrollbar(
                        thickness: 0,
                        scrollbarOrientation: ScrollbarOrientation.left,
                        child: SingleChildScrollView(
                          reverse: false,
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.removeFormat();
                                },
                                child: Text(
                                  "rich_remove".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  showColorPicker(context, Colors.black,
                                      (Color color) {
                                    setState(() {
                                      _jsApi.setTextColor(color.value);
                                    });
                                  });
                                },
                                child: Text(
                                  "rich_font_color".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  showColorPicker(context, Colors.black,
                                      (Color color) {
                                    setState(() {
                                      _jsApi
                                          .setTextBackgroundColor(color.value);
                                    });
                                  });
                                },
                                child: Text(
                                  "rich_bg_color".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: _selectText));
                                  Utils.showToast(
                                      context, "rich_copy_success".tr());
                                },
                                child: Text(
                                  "rich_copy".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  ClipboardData? data = await Clipboard.getData(
                                      Clipboard.kTextPlain);
                                  setState(() {
                                    Utils.showToast(
                                        context, "rich_paste_success".tr());
                                    _replaceSelectedText(data?.text);
                                    _isMenu = false;
                                  });
                                },
                                child: Text(
                                  "rich_paste".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setBold();
                                  // 执行JS代码，清除选区并将光标定位到选中文字最后
                                  // 替换你原来的代码，实现「清除选区 + 光标定位到原选区最后」
                                  setSelection();
                                },
                                child: Text(
                                  "rich_bold".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setItalic();
                                  setSelection();
                                },
                                child: Text(
                                  "rich_italic".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setUnderline();
                                  setSelection();
                                },
                                child: Text(
                                  "rich_underline".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setMobileTextColor("danger");
                                  setSelection();
                                },
                                child: Text(
                                  "rich_danger".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setMobileTextColor("success");
                                  setSelection();
                                },
                                child: Text(
                                  "rich_success".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setMobileTextColor("primary");
                                  setSelection();
                                },
                                child: Text(
                                  "rich_primary".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setMobileTextColor("warning");
                                  setSelection();
                                },
                                child: Text(
                                  "rich_warning".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onTap: () async {
                                  _jsApi.setMobileTextColor("black");
                                  setSelection();
                                },
                                child: Text(
                                  "rich_black".tr(),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onLongPress: () {},
                                onTap: () async {
                                  _jsApi.setFontSize("8");
                                  setSelection();
                                },
                                child: const Text(
                                  "8px",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onLongPress: () {},
                                onTap: () async {
                                  _jsApi.setFontSize("6");
                                  setSelection();
                                },
                                child: const Text(
                                  "6px",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onLongPress: () {},
                                onTap: () async {
                                  _jsApi.setFontSize("4");
                                  setSelection();
                                },
                                child: const Text(
                                  "4px",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              InkWell(
                                onLongPress: () {},
                                onTap: () async {
                                  _jsApi.setFontSize("2");
                                  setSelection();
                                },
                                child: const Text(
                                  "2px",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              // SizedBox(
                              //   width: 20,
                              // ),InkWell(
                              //   onLongPress: () {},
                              //   onTap: () async {
                              //     _jsApi.setFontSize("Monaco");
                              //     setSelection();
                              //   },
                              //   child: const Text(
                              //     "Monaco",
                              //     style: TextStyle(fontSize: 16),
                              //   ),
                              // ),
                              // SizedBox(
                              //   width: 20,
                              // ),InkWell(
                              //   onLongPress: () {},
                              //   onTap: () async {
                              //     _jsApi.setFontName("SimSun");
                              //     setSelection();
                              //   },
                              //   child: const Text(
                              //     "SimSun",
                              //     style: TextStyle(fontSize: 16),
                              //   ),
                              // ),
                              SizedBox(
                                width: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_isToolBarVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 单独处理保存按钮（复用封装方法）
                    _buildToolbarIcon(
                      icon: Icons.save,
                      onPressed: () {
                        _saveContent();
                      },
                    ),
                    _buildToolbarIcon(
                      icon: Icons.undo,
                      onPressed: () {
                        _toggleIconState(Icons.undo);
                        _jsApi.undo();
                      },
                    ),
                    _buildToolbarIcon(
                      icon: Icons.redo,
                      onPressed: () {
                        _toggleIconState(Icons.redo);
                        _jsApi.redo();
                      },
                    ),
                    Expanded(
                      child: Scrollbar(
                        thickness: 0,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          reverse: true,
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildToolbarIcon(
                                icon: Icons.date_range,
                                onPressed: () {
                                  _jsApi.insertDateTime();
                                  // _jsApi.setFontSize("30");
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.line_axis_outlined,
                                onPressed: () {
                                  _jsApi.insertDivider();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.h_mobiledata,
                                onPressed: () {
                                  _showHeadingDialog();
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.toc_sharp,
                                onPressed: () {
                                  _showTocConfirmDialog();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_color_text,
                                onPressed: () {
                                  _showEditDialog("rich_set_font_size".tr(), 3);
                                  // SystemChannels.textInput
                                  //     .invokeMethod('TextInput.hide');
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_bold,
                                onPressed: () {
                                  _toggleIconState(Icons.format_bold);
                                  _jsApi.setBold();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_italic,
                                onPressed: () {
                                  _toggleIconState(Icons.format_italic);
                                  _jsApi.setItalic();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.subscript,
                                onPressed: () {
                                  _toggleIconState(Icons.subscript);
                                  _jsApi.setSubscript();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.superscript,
                                onPressed: () {
                                  _toggleIconState(Icons.subscript);
                                  _jsApi.setSuperscript();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_underline,
                                onPressed: () {
                                  _toggleIconState(Icons.format_underline);
                                  _jsApi.setUnderline();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_list_bulleted,
                                onPressed: () {
                                  _toggleIconState(Icons.format_list_bulleted);
                                  _jsApi.setBullets();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_indent_decrease,
                                onPressed: () {
                                  _toggleIconState(
                                      Icons.format_indent_decrease);
                                  _jsApi.setIndent();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_indent_increase_outlined,
                                onPressed: () {
                                  _toggleIconState(
                                      Icons.format_indent_increase_outlined);
                                  _jsApi.setOutdent();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_align_center,
                                onPressed: () {
                                  _toggleIconState(Icons.format_align_center);
                                  _jsApi.setAlignCenter();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_align_left,
                                onPressed: () {
                                  _toggleIconState(Icons.format_align_left);
                                  _jsApi.setAlignLeft();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_align_right,
                                onPressed: () {
                                  _toggleIconState(Icons.format_align_right);
                                  _jsApi.setAlignRight();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_quote,
                                onPressed: () {
                                  _toggleIconState(Icons.format_quote);
                                  _jsApi.setBlockquote();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_list_numbered,
                                onPressed: () {
                                  _toggleIconState(Icons.format_list_numbered);
                                  _jsApi.setNumbers();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.format_strikethrough,
                                onPressed: () {
                                  _toggleIconState(Icons.format_strikethrough);
                                  _jsApi.setStrikeThrough();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.code,
                                onPressed: () {
                                  _toggleIconState(Icons.code);
                                  _jsApi.insertCodeBlock(); // 注意：这里逻辑需确认
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.color_lens,
                                onPressed: () {
                                  // _toggleIconState(Icons.check_box);
                                  // _jsApi.setTodo(""); // 注意：这里逻辑需确认
                                  _showColorOptionDialog();
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                },
                              ),
                              // _buildToolbarIcon(
                              //   icon: Icons.format_color_fill_rounded,
                              //   onPressed: () {
                              //     // _toggleIconState(Icons.check_box);
                              //     // _jsApi.setTodo(""); // 注意：这里逻辑需确认
                              //     _showBaseColorOptionDialog();
                              //     SystemChannels.textInput
                              //         .invokeMethod('TextInput.hide');
                              //   },
                              // ),
                              _buildToolbarIcon(
                                icon: Icons.tag,
                                onPressed: () {
                                  _jsApi.insertTag("rich_label".tr());
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.close_fullscreen_rounded,
                                onPressed: () {
                                  _jsApi.insertCollapsible("");
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.html,
                                onPressed: () {
                                  _toggleIconState(Icons.check_box);
                                  _showEditDialog(
                                      "rich_set_html".tr(), 4); // 注意：这里逻辑需确认
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.check_box_outline_blank,
                                onPressed: () {
                                  _toggleIconState(Icons.check_box);
                                  _jsApi.setTodo("", "false"); // 注意：这里逻辑需确认
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.check_box,
                                onPressed: () {
                                  _toggleIconState(Icons.check_box);
                                  _jsApi.setTodo("", "true"); // 注意：这里逻辑需确认
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.image,
                                onPressed: () {
                                  _toggleIconState(Icons.image);
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                  _showImageOptionDialog();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.audiotrack,
                                onPressed: () {
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                  _showAudioOptionDialog();
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.video_call,
                                onPressed: () {
                                  _toggleIconState(Icons.videocam);
                                  _showVideoOptionDialog();
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.table_chart_outlined,
                                onPressed: () {
                                  _showEditorDialog("rich_set_table_row".tr(),
                                      "rich_set_table_cols".tr(), 0);
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.link,
                                onPressed: () {
                                  _toggleIconState(Icons.link);
                                  _showEditorDialog("rich_set_link_name".tr(),
                                      "rich_set_link".tr(), 1);
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                },
                              ),
                              _buildToolbarIcon(
                                icon: Icons.rocket_launch_rounded,
                                onPressed: () {
                                  // _toggleIconState(Icons.link);
                                  // _jsApi.removeFormat();
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                  _showModelOptionDialog();
                                },
                              ),

                              _buildToolbarIcon(
                                icon: Icons.format_clear,
                                onPressed: () {
                                  // _toggleIconState(Icons.link);
                                  _jsApi.removeFormat();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 启动本地HTTP服务器
  Future<void> _startLocalServer(String videoPath) async {
    // 避免端口占用，尝试切换端口
    while (_localServer == null) {
      try {
        _localServer =
            await HttpServer.bind(InternetAddress.loopbackIPv4, _serverPort);
        break;
      } catch (e) {
        _serverPort++; // 端口被占用则+1
      }
    }

    if (_localServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地服务器启动失败')),
      );
      return;
    }

    // 配置文件服务器，映射视频文件路径
    final fileServer = VirtualDirectory(path.dirname(videoPath))
      ..allowDirectoryListing = false
      ..jailRoot = false; // 允许访问指定目录的文件

    // 监听HTTP请求，返回视频文件
    _localServer!.listen((request) {
      final videoFileName = path.basename(videoPath);
      // 只响应视频文件的请求
      if (request.uri.path == '/$videoFileName') {
        fileServer.serveFile(File(videoPath), request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });
  }

  // 停止本地服务器
  Future<void> _stopLocalServer() async {
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
    }
  }

  Future<void> _pickAudioFromGallery() async {
    try {
      // 选择本地视频文件（支持mp4/avi等格式）
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      // if (result != null && result.files.isNotEmpty) {
      //   final String audioPath = result.files.first.path!;
      //   _jsApi.insertAudio("file://" + audioPath);
      // }

      if (result != null && result.files.isNotEmpty) {
        DialogWidget.show(context: context);
        final file = await FileUtils.saveImageToDir(result);
        if (file == null) {
          DialogWidget.dismiss(context);
          Utils.showToast(context, "import_failed".tr());
        } else {
          DialogWidget.dismiss(context);
          final String audioPath = file.path;
          _jsApi.insertAudio("file://" + audioPath);
        }
      }
    } catch (e) {
      Utils.showToast(context, "message" + e.toString());
    }
  }

  // 选择本地视频并插入到WebView
  Future<void> _pickVideoFromGallery() async {
    try {
      // 选择本地视频文件（支持mp4/avi等格式）
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.isNotEmpty) {
        DialogWidget.show(context: context);
        final file = await FileUtils.saveImageToDir(result);
        if (file == null) {
          DialogWidget.dismiss(context);
          Utils.showToast(context, "import_failed".tr());
        } else {
          DialogWidget.dismiss(context);
          final String videoPath = file.path;
          _jsApi.insertVideo("file://" + videoPath);
        }
      }
    } catch (e) {
      Utils.showToast(context, "message" + e.toString());
    }
  }

  // 优化：图片选择+压缩，解决大图片内存问题
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedImage != null) {
        DialogWidget.show(context: context);
        final file = await FileUtils.saveImageToDir(pickedImage);
        if (file == null) {
          DialogWidget.dismiss(context);
          Utils.showToast(context, "import_failed".tr());
        } else {
          DialogWidget.dismiss(context);
          String path = "file://" + file.path;
          await _executeJS(
            webController!,
            "if (typeof Rich !== 'undefined') { Rich.insertImage('$path', '图片描述'); }",
          );
          if (mounted) {
            Utils.showToast(context, "rich_image_inserted".tr());
          }
        }
      }
    } catch (e) {
      ///debugPrint("选择图片失败：$e");
      if (mounted) {
        Utils.showToast(context, "rich_image_failed".tr());
      }
    }
  }

  Future<void> _showEditorDialog(
      String hintText, String _hinText, int type) async {
    final TextEditingController controller = TextEditingController();
    final TextEditingController _controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hintText),
              autofocus: true,
            ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(hintText: _hinText),
              autofocus: true,
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 监听流式响应
              switch (type) {
                case 0:
                  _jsApi.insertTable(controller.text, _controller.text);
                  break;
                case 1:
                  _jsApi.insertLink(_controller.text, controller.text);
                  break;

                  break;
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(String hintText, int type) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 监听流式响应
              switch (type) {
                case 0:
                  _jsApi.insertImage(controller.text, "alt");
                  break;
                case 1:
                  _jsApi.insertLink(controller.text, controller.text);
                  break;
                case 2:
                  _jsApi.insertVideoW(controller.text, "100%");
                  break;
                case 3:
                  _jsApi.setFontSize(controller.text!);
                  _jsApi.focusEditor();
                  break;
                case 4:
                  _jsApi.insertHtml(controller.text);
                  break;
                case 5:
                  _jsApi.insertAudio(controller.text);
                  break;
                case 6:
                  _jsApi.insertMathFormula(controller.text);
                  break;
                case 7:
                  _jsApi.insertVideoBliBli(controller.text);
                  break;
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  void _onItemTap(FileSystemEntity entity) async {
    if (entity is File && path.extension(entity.path) == '.mgtx') {
      final fileName = path.basenameWithoutExtension(entity.path);
      // _showDialog(entity.path);
      final content = await FileUtils.readHtmlFile(entity.path);
      setState(() {
        _executeJS(
            webController!,
            "javascript:Rich.insertHtmlModel('" +
                base64Encode(utf8.encode(content.toString())) +
                "');");
        Utils.showToast(context, "插入成功");
      });
    } else if (entity is File && path.extension(entity.path) == '.mmd') {
      final fileName = path.basenameWithoutExtension(entity.path);
      // _showMdDialog(entity.path);
    }
  }

  void showColorPicker(
      BuildContext context, Color color, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ColorPicker(
              heading: Text('select_color'.tr()),
              subheading: Text('select_your_like_color'.tr()),
              tonalSubheading: Text('select_your_like_color'.tr()),
              wheelSubheading: Text('select_your_like_color'.tr()),
              recentColorsSubheading: Text('select_your_like_color'.tr()),
              opacitySubheading: Text('select_your_like_color'.tr()),
              color: Colors.blue,
              onColorChanged: (Color color) {
                setState(() {
                  // Colors.blue = color;
                  Navigator.pop(context); // 关闭弹窗
                  onColorChanged(color);
                });
              },
            ), // 这里需要一个自定义的 ColorPicker 小部件
          ),
        );
      },
    );
  }

  Color hexStringToColor(String hexStr, {String opacityHex = 'FF'}) {
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

  void _showBaseColorOptionDialog() {
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
                leading: const Icon(Icons.invert_colors_on_rounded),
                title: Text("rich_font_color".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  showColorPicker(context, Colors.black, (Color color) {
                    setState(() {
                      _jsApi.setEditorFontColor(color.value);
                    });
                  });
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.format_color_fill_rounded),
                title: Text("rich_bg_color".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  showColorPicker(context, Colors.black, (Color color) {
                    setState(() {
                      _jsApi.setBackgroundColor(color.value);
                    });
                  });
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

  void _showColorOptionDialog() {
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
                'rich_color_set'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.invert_colors_on_rounded),
                title: Text("rich_set_color".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  showColorPicker(context, Colors.black, (Color color) {
                    setState(() {
                      _jsApi.setTextColor(color.value);
                    });
                  });
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.format_color_fill_rounded),
                title: Text("rich_set_font_bg_color".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  showColorPicker(context, Colors.black, (Color color) {
                    setState(() {
                      _jsApi.setTextBackgroundColor(color.value);
                    });
                  });
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

  void _showAudioOptionDialog() {
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
                'rich_insert_audio'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text("rich_insert_audio".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  _showEditDialog("rich_insert_audio".tr(), 5);
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.multitrack_audio_rounded),
                title: Text("rich_select_audio".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _pickAudioFromGallery(); // 调用图库选择方法
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

  List<FileSystemEntity> fileList = [];
  void _showModelOptionDialog() {
    showModalBottomSheet(
      context: context,
      // 关键修改1：允许弹窗高度自适应（解决高内容溢出屏幕问题）
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'rich_insert_model'.tr(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接+选择图片选项行
            Row(
              children: [
                Expanded(
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.credit_card_sharp),
                      title: Text("rich_insert_model_card".tr()),
                      onTap: () {
                        Navigator.pop(context); // 关闭弹窗
                        _jsApi.insertInfoCard();
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.videocam),
                      title: Text("rich_insert_model_blibli".tr()),
                      onTap: () {
                        Navigator.pop(context); // 关闭弹窗
                        _showEditDialog(
                            "rich_insert_model_blibli_hint".tr(), 7);
                      },
                    ),
                  ),
                ),
              ],
            ),
            // 关键修改2：用Expanded包裹列表，让列表占据剩余空间

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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  width: double.infinity,
                  child: Center(
                    child: Text('cancel'.tr(),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 弹出选择弹窗：输入链接 / 选择图片
  void _showVideoOptionDialog() {
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
                'rich_insert_video'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.slow_motion_video_rounded),
                title: Text("rich_insert_video".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  _showEditDialog("rich_insert_video".tr(), 2);
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.videocam),
                title: Text("rich_select_video".tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _pickVideoFromGallery(); // 调用图库选择方法
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
                'rich_insert_image'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text('rich_insert_image'.tr()),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  _showEditDialog("rich_insert_image".tr(), 0);
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('rich_select_image'.tr()),
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
            if (imageUrl != null) {
              await _executeJS(
                webController!,
                "if (typeof Rich !== 'undefined') { Rich.insertImage('$imageUrl', '图片描述'); }",
              );
              if (mounted) {
                Utils.showToast(context, "rich_image_inserted".tr());
              }
            }
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

  void _showHeadingDialog() {
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
                "rich_select_head".tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 输入链接选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.h_mobiledata_sharp),
                title: Text("H1"),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  // 调用 wrapMarkdown：光标定位到 url 位置
                  _jsApi.setHeading(1);
                },
              ),
            ),
            // 选择图片选项
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.h_mobiledata_sharp),
                title: Text("H2"),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _jsApi.setHeading(2); // 调用图库选择方法
                },
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.h_mobiledata_sharp),
                title: Text("H3"),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _jsApi.setHeading(3); // 调用图库选择方法
                },
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.h_mobiledata_sharp),
                title: Text("H4"),
                onTap: () {
                  Navigator.pop(context); // 关闭弹窗
                  _jsApi.setHeading(4); // 调用图库选择方法
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

  // 构建工具栏图标按钮（增加选中状态样式）

  /// 封装带选中状态的工具栏按钮
  Widget _buildToolbarIcon({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    // 获取当前图标是否选中
    bool isSelected = _iconSelectedStates[icon] ?? false;
    // 选中时的背景色（可自定义）
    Color selectedBgColor = Colors.grey[300]!;
    // 选中时的边框色（可自定义）
    Color selectedBorderColor = Colors.blueGrey;
    bool isActive = _isIconActive(icon);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        style: ButtonStyle(
          // 动态背景色：选中时变深，未选中时透明
          backgroundColor: MaterialStateProperty.all(
            isActive ? selectedBgColor : Colors.transparent,
          ),
          // 动态边框色：选中时变色，增强视觉效果
          side: MaterialStateProperty.all(
            BorderSide(
              color: Colors.grey,
              width: 1.0,
            ),
          ),
          shape: MaterialStateProperty.all(const CircleBorder()),
          padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
        ),
      ),
    );
  }
}
