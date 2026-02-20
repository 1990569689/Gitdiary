import 'dart:convert';

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/generators/custom_node.dart';
import 'package:editor/generators/video.dart';
import 'package:editor/provider.dart';
import 'package:editor/rich/api.dart';
import 'package:editor/theme.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/config/markdown_generator.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/blocks/container/blockquote.dart';
import 'package:markdown_widget/widget/blocks/container/list.dart';
import 'package:markdown_widget/widget/blocks/container/table.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
import 'package:markdown_widget/widget/blocks/leaf/link.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/inlines/code.dart';
import 'package:markdown_widget/widget/inlines/img.dart';
import 'package:markdown_widget/widget/inlines/input.dart';
import 'package:markdown_widget/widget/markdown.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class Model extends StatefulWidget {
  @override
  State<Model> createState() => _ModelState();
}

class _ModelState extends State<Model> with SingleTickerProviderStateMixin {
  final Map<String, dynamic> config = Utils.getWriteConfig();
  String _quoteTextColor = "";

  String _linkColor = "";
  String _quoteColor = "";
  String _codeFontColor = "";
  String _codeBgColor = "";
  int _imageQuality = 80;
  int _autoTimes = 5;
  int _render = 0;
  double _fontSize = 12.0;
  bool _switchValue1 = true;
  FilterQuality _filterQuality = FilterQuality.high;

  InAppWebViewController? webController;
  int currentIndex = 0;
  static const String _callbackScheme = "re-callback://";
  static const String _stateScheme = "re-state://";
  static const String _todoScheme = "re-undo-redo://";
  static const String _saveScheme = "re-save-image://";
  static const String _stateHtmlScheme = "re-state-html://";
  final InAppWebViewGroupOptions _webViewOptions = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      horizontalScrollBarEnabled: false,
      verticalScrollBarEnabled: false,
      transparentBackground: true,
      // 新增：减少渲染延迟
      useOnLoadResource: false,
      supportZoom: false,
      disableContextMenu: true,
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

  final List<String> tabs =  ["rich".tr(), "markdown".tr(), "online".tr()];
  late TabController _controller;
  late PageController _pageController;
  final Set<dynamic> _selectedIds = {};
  bool _isEditMode = false;
  List<FileSystemEntity> _md_fileList = [];
  List<FileSystemEntity> _gtx_fileList = []; // 过滤后的文件列表（用于展示）
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
  // 显示错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('tip'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
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

  Future<void> _loadAssetsHtml() async {
    if (webController == null) return;
    if (ThemeUtil.getIsDark()) {
      await webController?.loadFile(
          assetFilePath: 'assets/html/editor-dark.html');
    } else {
      await webController?.loadFile(assetFilePath: 'assets/html/editor.html');
    }

    setState(() {});
  }

  // 参考官方示例：初始化编辑器控制器
  Future<void> _initController(String filePath) async {
    try {
      final content = await FileUtils.readHtmlFile(filePath);
      setState(() {
        // Utils.showToast(context, "" + content);

        _executeJS(
            webController!,
            "javascript:Rich.setHtml('" +
                base64Encode(utf8.encode(content.toString())) +
                "');");
      });
    } catch (e) {}
  }

  Future<void> _showMdDialog(String filePath) async {
    final text = await FileUtils.readMdFile(filePath);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // contentPadding: EdgeInsets.zero,
        // // 设置弹窗整体的最小宽度，适配手机端
        // insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: Container(
          // 给WebView添加少量内边距，避免边缘紧贴
          padding: const EdgeInsets.all(8),

          width: double.infinity,
          height: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: MarkdownBlock(
              data: text,
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
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ListConfig(
                    marginLeft: 32.0,
                    marginBottom: 4.0,
                    marker: (isOrdered, depth, index) {
                      if (isOrdered) {
                        return Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(right: 1),
                            child: SelectionContainer.disabled(
                                child: Text(
                              '${index + 1}.',
                              style: TextStyle(fontSize: _fontSize),
                            )));
                      }
                    },
                  ),
                  TableConfig(
                    defaultColumnWidth: FlexColumnWidth(1),
                    // defaultVerticalAlignment:
                    //     TableCellVerticalAlignment.fill,
                    // 1. 表格整体边框配置
                    border: TableBorder(
                      top: BorderSide(color: Colors.grey, width: 1),
                      right: BorderSide(color: Colors.grey, width: 1),
                      bottom: BorderSide(color: Colors.grey, width: 1),
                      left: BorderSide(color: Colors.grey, width: 1),
                      borderRadius: BorderRadius.circular(8), // 表格圆角
                      horizontalInside:
                          BorderSide(color: Colors.grey, width: 1),
                      verticalInside: BorderSide(color: Colors.grey, width: 1),
                    ),
                    // 2. 单元格内边距
                    bodyPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          color: hexStringToColor(_codeBgColor != ""
                              ? _codeBgColor
                              : Colors.black.value
                                  .toRadixString(16)
                                  .substring(2))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  BlockquoteConfig(
                      textColor: hexStringToColor(_quoteTextColor != ""
                          ? _quoteTextColor
                          : Colors.black.value.toRadixString(16).substring(2)),
                      sideColor: hexStringToColor(_quoteColor != ""
                          ? _quoteColor
                          : Colors.grey.value.toRadixString(16).substring(2))),
                  CodeConfig(
                      style: TextStyle(
                    fontSize: _fontSize,
                    color: hexStringToColor(_codeFontColor != ""
                        ? _codeFontColor
                        : Colors.black.value.toRadixString(16).substring(2)),
                    backgroundColor: const Color.fromARGB(0, 146, 7, 7),
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
                        crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中核心
                        mainAxisAlignment: MainAxisAlignment.center,
                        verticalDirection: VerticalDirection.down,
                        children: [
                          SizedBox(
                            // width: double.maxFinite,
                            // height: double.maxFinite,
                            // width: 20, // 固定checkbox宽度，避免尺寸波动
                            // height: 20, // 固定高度，匹配文字行高
                            child: Checkbox(
                              value: checked,
                              // 移除默认内边距，缩小checkbox尺寸
                              visualDensity: VisualDensity.compact,
                              // 取消点击水波纹的额外尺寸
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                        borderRadius: BorderRadius.circular(10),
                        child: url.toString().startsWith('http') ||
                                url.toString().startsWith('https')
                            ? Center(
                                child: CachedNetworkImage(
                                filterQuality: _filterQuality,
                                imageUrl: url.toString(),
                                fit: BoxFit.cover, // 确保图片覆盖整个容器
                                alignment: Alignment.center, // 确保图片居中
                                // 加载中占位
                                placeholder: (context, url) => const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),

                                // 加载失败占位
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              ))
                            : Image.file(
                                errorBuilder: (context, error, stackTrace) {
                                  return Text("image_error".tr());
                                },
                                File(url.toString()),
                                filterQuality: _filterQuality,
                                fit: BoxFit.cover, // 确保图片覆盖整个容器
                                alignment: Alignment.center, // 确保图片居中
                              ),
                      );
                    },
                  ),
                  LinkConfig(
                    style: TextStyle(
                        fontSize: _fontSize,
                        color: hexStringToColor(_linkColor != ""
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(String filePath) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 移除默认内边距，避免内容被挤压
        contentPadding: EdgeInsets.zero,
        // 设置弹窗整体的最小宽度，适配手机端
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: Container(
          // 核心：设置弹窗高度为400
          height: 400,
          // 宽度充满屏幕（减去弹窗默认的内边距）
          width: double.infinity,
          // 给WebView添加少量内边距，避免边缘紧贴
          padding: const EdgeInsets.all(8),
          child: InAppWebView(
            // pullToRefreshController:
            // 2. 监听长按事件
            onLongPressHitTestResult: (controller, hitTestResult) async {
              if (hitTestResult.type ==
                  InAppWebViewHitTestResultType.EDIT_TEXT_TYPE) {
                // 获取选中的文本
                String? selectedText = await controller.getSelectedText();
              } else if (hitTestResult.type ==
                  InAppWebViewHitTestResultType.IMAGE_TYPE) {
                String? src = await hitTestResult?.extra.toString();
                if (src != null) {
                  if (src!.startsWith("http://") ||
                      src!.startsWith("https://")) {}
                }
              } else if (hitTestResult.type ==
                  InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE) {
                String? src = await hitTestResult?.extra.toString();
                if (src != null) {
                  if (src!.startsWith("http://") ||
                      src!.startsWith("https://")) {}
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
                _loadAssetsHtml();
              });
              // 可选：设置用户代理
            },
            // 加载进度回调
            onProgressChanged: (controller, progress) {
              setState(() {});
            },
            // 页面标题变化
            onTitleChanged: (controller, title) {
              setState(() {});
            },
            // 页面加载完成
            onLoadStop: (controller, url) async {
              // 可选：隐藏进度条（进度设为1）
              setState(() {
                _initController(filePath);

                //
              });
            },
            // 加载失败
            onLoadError: (controller, url, code, message) {},
            // URL跳转拦截（比如拦截外部链接、自定义跳转）
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? "";
              final String decodeUrl = Uri.decodeComponent(url);
              // 处理文本变化回调
              if (url.contains(_callbackScheme)) {
                return NavigationActionPolicy.CANCEL;
              }
              //处理格式状态回调
              else if (url.contains(_stateScheme)) {
                // final String decodeUrl = Uri.decodeFull(url);
                final String state =
                    url.replaceFirst(_stateScheme, "").toUpperCase();
                setState(() {
                  // 清空原有状态

                  // 分割状态字符串（假设状态用逗号/空格分隔，如"BOLD,ITALIC"）
                  final List<String> stateItems = state.split(RegExp(r'[, ]+'));
                  // 匹配并添加激活的格式
                  for (var item in stateItems) {
                    final FormatType? type = FormatType.fromName(item);
                    if (type != null) {}
                  }
                });
                return NavigationActionPolicy.CANCEL;
              } else if (url.contains(_todoScheme)) {
                return NavigationActionPolicy.CANCEL;
              } else if (url.contains(_saveScheme)) {
                final String state =
                    url.replaceFirst(_saveScheme, "").toString();
                // Utils.showToast(context, "保存成功" + state);
                // await FileUtils.saveNetworkImageToGallery(state);
                //Utils.showToast(context, "保存成功");
                return NavigationActionPolicy.CANCEL;
              } else if (url.contains(_stateHtmlScheme)) {
                SystemChannels.textInput.invokeMethod('TextInput.hide');
                return NavigationActionPolicy.CANCEL;
              } else {
                return NavigationActionPolicy.CANCEL;
              }
            },
          ),
        ),
      ),
    );
  }
  // Future<void> _showDialog(String filePath) async {
  //   final TextEditingController controller = TextEditingController();
  //   await showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       content: InAppWebView(

  //           // pullToRefreshController:
  //           // 2. 监听长按事件
  //           onLongPressHitTestResult: (controller, hitTestResult) async {
  //             if (hitTestResult.type ==
  //                 InAppWebViewHitTestResultType.EDIT_TEXT_TYPE) {
  //               // 获取选中的文本
  //               String? selectedText = await controller.getSelectedText();
  //             } else if (hitTestResult.type ==
  //                 InAppWebViewHitTestResultType.IMAGE_TYPE) {
  //               String? src = await hitTestResult?.extra.toString();
  //               if (src != null) {
  //                 if (src!.startsWith("http://") ||
  //                     src!.startsWith("https://")) {}
  //               }
  //             } else if (hitTestResult.type ==
  //                 InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE) {
  //               String? src = await hitTestResult?.extra.toString();
  //               if (src != null) {
  //                 if (src!.startsWith("http://") ||
  //                     src!.startsWith("https://")) {}
  //               }
  //             }
  //           },
  //           // contextMenu: _contextMenu,

  //           // 初始加载的URL
  //           // 核心配置
  //           initialOptions: _webViewOptions,
  //           // WebView创建完成（获取控制器）
  //           onWebViewCreated: (controller) {
  //             webController = controller;
  //             setState(() {
  //               _loadAssetsHtml();
  //             });
  //             // 可选：设置用户代理
  //           },
  //           // 加载进度回调
  //           onProgressChanged: (controller, progress) {
  //             setState(() {});
  //           },
  //           // 页面标题变化
  //           onTitleChanged: (controller, title) {
  //             setState(() {});
  //           },
  //           // 页面加载完成
  //           onLoadStop: (controller, url) async {
  //             // 可选：隐藏进度条（进度设为1）
  //             setState(() {
  //               _initController(filePath);

  //               //
  //             });
  //           },
  //           // 加载失败
  //           onLoadError: (controller, url, code, message) {},
  //           // URL跳转拦截（比如拦截外部链接、自定义跳转）
  //           shouldOverrideUrlLoading: (controller, navigationAction) async {
  //             final url = navigationAction.request.url?.toString() ?? "";
  //             final String decodeUrl = Uri.decodeComponent(url);
  //             // 处理文本变化回调
  //             if (url.contains(_callbackScheme)) {
  //               return NavigationActionPolicy.CANCEL;
  //             }
  //             //处理格式状态回调
  //             else if (url.contains(_stateScheme)) {
  //               // final String decodeUrl = Uri.decodeFull(url);
  //               final String state =
  //                   url.replaceFirst(_stateScheme, "").toUpperCase();
  //               setState(() {
  //                 // 清空原有状态

  //                 // 分割状态字符串（假设状态用逗号/空格分隔，如"BOLD,ITALIC"）
  //                 final List<String> stateItems = state.split(RegExp(r'[, ]+'));
  //                 // 匹配并添加激活的格式
  //                 for (var item in stateItems) {
  //                   final FormatType? type = FormatType.fromName(item);
  //                   if (type != null) {}
  //                 }
  //               });
  //               return NavigationActionPolicy.CANCEL;
  //             } else if (url.contains(_todoScheme)) {
  //               return NavigationActionPolicy.CANCEL;
  //             } else if (url.contains(_saveScheme)) {
  //               final String state =
  //                   url.replaceFirst(_saveScheme, "").toString();
  //               // Utils.showToast(context, "保存成功" + state);
  //               // await FileUtils.saveNetworkImageToGallery(state);
  //               //Utils.showToast(context, "保存成功");
  //               return NavigationActionPolicy.CANCEL;
  //             } else if (url.contains(_stateHtmlScheme)) {
  //               SystemChannels.textInput.invokeMethod('TextInput.hide');
  //               return NavigationActionPolicy.CANCEL;
  //             } else {
  //               return NavigationActionPolicy.CANCEL;
  //             }
  //           }),
  //     ),
  //   );
  // }

  @override
  void dispose() {
    // _controller.removeListener(_handleTab);
    _controller.dispose();
    _pageController.dispose(); // 新增：释放PageController
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    UpdateProvider update = Provider.of<UpdateProvider>(context, listen: false);
    load();
    update.addListener(load);

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

    _pageController = PageController(initialPage: 0); // 初始化默认选中第一个tab
    _controller = TabController(length: tabs.length, vsync: this);

    // 监听PageView滑动，同步TabController
    _pageController.addListener(() {
      setState(() {
        currentIndex = _pageController.page?.round() ?? 0;
        if (_controller.index != currentIndex) {
          _controller.animateTo(
            currentIndex,
            duration: const Duration(milliseconds: 150),
            curve: Curves.ease,
          );
        }
      });
    });

    // 计算缓存大小
  }

  void load() {
    _loadFiles("gtx_model");
    _loadFiles("md_model");
  }
  // void _handleTab() {
  //   if (_controller.indexIsChanging) {
  //     setState(() {
  //       Utils.showToast(context, "" + _controller.index.toString());
  //       currentIndex = _controller.index;
  //     });
  //   }
  // }

  // 修改：加载文件列表（区分原始列表和过滤列表）
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
        _gtx_fileList = entities;
      } else {
        _md_fileList = entities;
      }
    });
  }

  // 原有方法：获取修改时间（保留）
  Future<String> _getModifiedTime(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      return _dateFormatter.format(stat.modified);
    } catch (e) {
      return 'unknown_time'.tr();
    }
  }

  // 新增：空列表占位组件
  Widget _buildEmptyWidget(String tip) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_sharp, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            tip,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 新增：构建每个Tab对应的内容视图
  Widget _buildTabView(int index) {
    switch (index) {
      case 0: // 富文本
        return _gtx_fileList.isEmpty
            ? _buildEmptyWidget('model_not_rich'.tr())
            : ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: _gtx_fileList.length,
                itemBuilder: (context, index) =>
                    _buildListItem(_gtx_fileList[index]),
              );
      case 1: // Markdown
        return _md_fileList.isEmpty
            ? _buildEmptyWidget('model_not_markdown'.tr())
            : ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: _md_fileList.length,
                itemBuilder: (context, index) =>
                    _buildListItem(_md_fileList[index]),
              );
      case 2: // 在线
        return _buildEmptyWidget('model_not_online'.tr());
      default:
        return const SizedBox();
    }
  }

  // 原有方法：构建列表视图项（保留，优化了padding）
  Widget _buildListItem(FileSystemEntity entity) {
    final name = path.basename(entity.path).split(".").first;
    String e = path.extension(entity.path);
    final isDir = entity is Directory;
    final isSelected = _selectedIds.contains(entity);

    return FutureBuilder(
      future: Future.wait([_getModifiedTime(entity)]),
      initialData: ['loading'.tr(), ''],
      builder: (context, snapshot) {
        final modifyTime = snapshot.data?[0] ?? 'unknown_time'.tr();
        final previewContent = isDir ? 'folder'.tr() : '';
        //(snapshot.data?[0] ?? '')
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: ThemeUtil.getIsDark() ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: ThemeUtil.getIsDark()
                    ? const Color.fromARGB(115, 153, 153, 153)
                    : Colors.grey.shade100,
                blurRadius: 2,
                // offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDir ? Colors.blue[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    size: 20,
                    isDir
                        ? Icons.folder
                        : e == ".md"
                            ? Icons.article_outlined
                            : Icons.edit_document,
                    color: isDir ? Colors.blue[700] : Colors.grey[600],
                  ),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${'modify_time'.tr()}${modifyTime}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                  if (_isEditMode) {
                    //_toggleItemSelection(entity);
                  } else {
                    _onItemTap(entity);
                  }
                },
                onLongPress: () => _showOptionDialog(entity),
              ),
              if (_isEditMode)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 原有方法：单个删除（保留）
  Future<void> _showDeleteConfirmDialog(FileSystemEntity entity) async {
    final String name = path.basename(entity.path);
    final String type = entity is Directory ? 'folder'.tr() : 'file'.tr();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('confirm_delete_hint'.tr()),
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
                if (entity is Directory) {
                  await entity.delete(recursive: true);
                } else {
                  await entity.delete();
                }
                _loadFiles(path.dirname(entity.path).split("/").last);
                if (mounted) {
                  Utils.showToast(context, 'delete_success'.tr());
                }
              } catch (e) {
                if (mounted) {
                  Utils.showToast(context, 'delete_failed'.tr());
                }
              }
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  // 原有方法：重命名对话框（保留）
  Future<void> _showRenameDialog(FileSystemEntity entity) async {
    final String originalName = path.basename(entity.path);
    final String extension = path.extension(entity.path);
    final String baseName = path.basenameWithoutExtension(entity.path);

    final TextEditingController _controller = TextEditingController(
      text: baseName,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('rename'.tr()),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'enter_new_name'.tr(),
            errorText: null,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\/:*?"<>|]')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () async {
              final String newBaseName = _controller.text.trim();
              if (newBaseName.isEmpty) {
                if (mounted) {
                  Utils.showToast(context, 'name_empty'.tr());
                }
                return;
              }
              if (newBaseName == baseName) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);

              try {
                final String parentDir = path.dirname(entity.path);
                final String newName =
                    entity is File ? '$newBaseName$extension' : newBaseName;
                final String newPath = path.join(parentDir, newName);

                if (await File(newPath).exists() ||
                    await Directory(newPath).exists()) {
                  if (mounted) {
                    Utils.showToast(context, 'name_already_exists'.tr());
                  }
                  return;
                }

                await entity.rename(newPath);
                _loadFiles(path.dirname(entity.path).split("/").last);

                if (mounted) {
                  Utils.showToast(context, 'rename_success'.tr());
                }
              } catch (e) {
                if (mounted) {
                  Utils.showToast(context, 'rename_failed'.tr());
                }
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  void _showOptionDialog(FileSystemEntity entity) {
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
                'more_options'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text('rename'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  _showRenameDialog(entity);
                },
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.delete),
                title: Text('delete'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(entity);
                },
              ),
            ),
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

  // 原有方法：点击文件/文件夹（保留）
  void _onItemTap(FileSystemEntity entity) {
    if (entity is File && path.extension(entity.path) == '.mgtx') {
      final fileName = path.basenameWithoutExtension(entity.path);
      _showDialog(entity.path);
    } else if (entity is File && path.extension(entity.path) == '.mmd') {
      final fileName = path.basenameWithoutExtension(entity.path);
      _showMdDialog(entity.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          ThemeUtil.getIsDark() ? Colors.black : Colors.grey.shade50, // 页面背景色优化
      body: Column(
        children: [
          // 优化后的TabBar容器
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: ThemeUtil.getIsDark() ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  // offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              onTap: (index) {
                // Tab 被点击
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              // 核心：自定义选中样式
              indicator: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: tabs
                  .map((e) => Tab(
                        text: e, // 简化Tab内容，去掉多余Container
                      ))
                  .toList(),
              controller: _controller,
              isScrollable: false,
              // 去掉默认的底部边框
              dividerColor: Colors.transparent,
            ),
          ),
          // 内容区域
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: tabs.length,
              physics: const BouncingScrollPhysics(), // 手机端滑动体验优化
              itemBuilder: (context, index) {
                return _buildTabView(index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
