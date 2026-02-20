import 'dart:io';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:editor/widget/switch_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class NotePage extends StatefulWidget {
  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
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
  String _linkColor = "";
  int _render = 0;
  String _quoteTextColor = "";
  String _quoteColor = "";
  String _codeFontColor = "";
  String _codeBgColor = "";
  int _imageQuality = 80;
  int _autoTimes = 5;
  double _fontSize = 20.0;
  bool _switchValue1 = false;
  @override
  void initState() {
    super.initState();
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
    // 计算缓存大小
  }

  Future<void> _showDialog({
    required String defaultValue,
    required String title,
    required String hintText,
  }) async {
    final TextEditingController controller = TextEditingController();
    controller.text = defaultValue;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
            onPressed: () async {
              setState(() {
                Utils.setDouble(
                    'write_font_size', double.parse(controller.text));
                _fontSize = double.parse(controller.text);
              });
              Navigator.pop(context);
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
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

  void _showChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: const Text('选择主题模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context,
                'markdwon_widget',
                0,
              ),
              _buildLanguageOption(
                context,
                'flutter_markdwon',
                1,
              ),
              _buildLanguageOption(
                context,
                'webview_markdown',
                2,
              ),
              _buildLanguageOption(
                context,
                'vditor',
                3,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String title, int mode) {
    return ListTile(
      title: Text(
        mode == 0
            ? 'markdown_widget'
            : mode == 1
                ? 'flutter_markdown'
                : mode == 2
                    ? 'webview_markdown'
                    : 'vditor',
      ),
      onTap: () {
        // 切换语言
        if (mode == 0) {
          Utils.setInt('write_mark_render', 0);
        } else if (mode == 1) {
          Utils.setInt('write_mark_render', 1);
        } else if (mode == 2) {
          Utils.setInt('write_mark_render', 2);
        } else if (mode == 3) {
          Utils.setInt('write_mark_render', 3);
        }
        setState(() {
          _render = mode;
        });
        Navigator.pop(context); // 关闭弹窗
      },
      subtitle: Text(
        mode == 0
            ? '支持Html界面美观'
            : mode == 1
                ? '不支持Html适合写日记'
                : mode == 2
                    ? 'WebView渲染支持图表公式'
                    : '支持即时渲染类Typora',
      ),
      trailing: (_render == 0 && mode == 0) ||
              (_render == 1 && mode == 1) ||
              (_render == 2 && mode == 2) ||
              (_render == 3 && mode == 3)
          ? Icon(
              Icons.check,
              color: Colors.blue,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.search),
          //   onPressed: () {},
          // ),
        ],
        flexibleSpace: Container(
          width: double.infinity,
        ),

        title: Text('write_settings'.tr()),
        centerTitle: true,
        // elevation: 1,
        // 移动端显示AppBar，桌面/平板端可以隐藏或调整
        //automaticallyImplyLeading: !useNavigationRail,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          // 适配iOS/Android：iOS默认回弹，Android需自定义
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        children: [
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  subtitle: Text(
                    _render == 0
                        ? "markdwon_widget"
                        : _render == 1
                            ? "flutter_markdwon":
                          _render==2
                            ? "webview_markdown":"vditor",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('markdown_render'.tr()),
                  leading: Icon(
                    Icons.tune_outlined,
                    size: 20,
                  ),
                  onTap: () {
                    _showChangeDialog(context);
                  },
                ),
                ListTile(
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexStringToColor(_linkColor != ""
                          ? _linkColor
                          : Colors.blue.value.toRadixString(16).substring(2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Text(
                    _linkColor != ""
                        ? '#${_linkColor}'
                        : '#${Colors.blue.value.toRadixString(16).substring(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    // style: TextStyle(
                    //     backgroundColor: hexStringToColor(_linkColor != ""
                    //         ? _linkColor
                    //         : Colors.blue.value
                    //             .toRadixString(16)
                    //             .substring(2))),
                  ),
                  title: Text('markdown_link_color'.tr()),
                  leading: Icon(
                    Icons.link,
                    size: 20,
                  ),
                  onTap: () {
                    showColorPicker(
                        context,
                        _linkColor != ""
                            ? Color(int.parse(_linkColor, radix: 16))
                            : Colors.blue, (Color color) {
                      setState(() {
                        _linkColor = color.value.toRadixString(16).substring(2);
                        Utils.setString('write_link_color',
                            color.value.toRadixString(16).substring(2));
                      });
                    });
                  },
                ),
                ListTile(
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexStringToColor(_quoteColor != ""
                          ? _quoteColor
                          : Colors.grey.value.toRadixString(16).substring(2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Text(
                    _quoteColor != ""
                        ? '#${_quoteColor}'
                        : '#${Colors.grey.value.toRadixString(16).substring(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    // style: TextStyle(
                    //     backgroundColor: hexStringToColor(_quoteColor != ""
                    //         ? _quoteColor
                    //         : Colors.grey.value
                    //             .toRadixString(16)
                    //             .substring(2))),
                  ),
                  title: Text('markdown_quote_color'.tr()),
                  leading: Icon(
                    Icons.format_quote,
                    size: 20,
                  ),
                  onTap: () {
                    showColorPicker(
                        context,
                        _quoteColor != ""
                            ? Color(int.parse(_quoteColor, radix: 16))
                            : Colors.grey, (Color color) {
                      setState(() {
                        _quoteColor =
                            color.value.toRadixString(16).substring(2);
                        Utils.setString('write_quote_color',
                            color.value.toRadixString(16).substring(2));
                      });
                    });
                  },
                ),
                ListTile(
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexStringToColor(_quoteTextColor != ""
                          ? _quoteTextColor
                          : Colors.grey.value.toRadixString(16).substring(2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Text(
                    _quoteTextColor != ""
                        ? '#${_quoteTextColor}'
                        : '#${Colors.grey.value.toRadixString(16).substring(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    // style: TextStyle(
                    //     backgroundColor: hexStringToColor(_quoteColor != ""
                    //         ? _quoteColor
                    //         : Colors.grey.value
                    //             .toRadixString(16)
                    //             .substring(2))),
                  ),
                  title: Text('markdown_quote_text_color'.tr()),
                  leading: Icon(
                    Icons.text_fields_sharp,
                    size: 20,
                  ),
                  onTap: () {
                    showColorPicker(
                        context,
                        _quoteTextColor != ""
                            ? Color(int.parse(_quoteTextColor, radix: 16))
                            : Colors.grey, (Color color) {
                      setState(() {
                        _quoteTextColor =
                            color.value.toRadixString(16).substring(2);
                        Utils.setString('write_quote_text_color',
                            color.value.toRadixString(16).substring(2));
                      });
                    });
                  },
                ),
                ListTile(
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexStringToColor(_codeFontColor != ""
                          ? _codeFontColor
                          : Colors.grey.value.toRadixString(16).substring(2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Text(
                    _codeFontColor != ""
                        ? '#${_codeFontColor}'
                        : '#${Colors.grey.value.toRadixString(16).substring(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    // style: TextStyle(
                    //     backgroundColor: hexStringToColor(_codeFontColor != ""
                    //         ? _codeFontColor
                    //         : Colors.grey.value
                    //             .toRadixString(16)
                    //             .substring(2))),
                  ),
                  title: Text('markdown_code_color'.tr()),
                  leading: Icon(
                    Icons.code,
                    size: 20,
                  ),
                  onTap: () {
                    showColorPicker(
                        context,
                        _codeFontColor != ""
                            ? Color(int.parse(_codeFontColor, radix: 16))
                            : Colors.grey, (Color color) {
                      setState(() {
                        _codeFontColor =
                            color.value.toRadixString(16).substring(2);
                        Utils.setString('write_code_font_color',
                            color.value.toRadixString(16).substring(2));
                      });
                    });
                  },
                ),
                ListTile(
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexStringToColor(_codeBgColor != ""
                          ? _codeBgColor
                          : Colors.grey.value.toRadixString(16).substring(2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Text(
                    _codeBgColor != ""
                        ? '#${_codeBgColor}'
                        : '#${Colors.grey.value.toRadixString(16).substring(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    // style: TextStyle(
                    //     backgroundColor: hexStringToColor(_codeBgColor != ""
                    //         ? _codeBgColor
                    //         : Colors.grey.value
                    //             .toRadixString(16)
                    //             .substring(2))),
                  ),
                  title: Text('markdown_code_background_color'.tr()),
                  leading: Icon(
                    Icons.colorize_rounded,
                    size: 20,
                  ),
                  onTap: () {
                    showColorPicker(
                        context,
                        _codeBgColor != ""
                            ? Color(int.parse(_codeBgColor, radix: 16))
                            : Colors.grey, (Color color) {
                      setState(() {
                        _codeBgColor =
                            color.value.toRadixString(16).substring(2);
                        Utils.setString('write_code_bg_color',
                            color.value.toRadixString(16).substring(2));
                      });
                    });
                  },
                ),
                ListTile(
                  subtitle: Text(
                    _fontSize.toString() != "" ? _fontSize.toString() : '20.0',
                    style: TextStyle(fontSize: 12.0, color: Colors.grey),
                  ),
                  title: Text('font_size'.tr()),
                  leading: Icon(
                    Icons.font_download,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                      defaultValue: _fontSize.toString(),
                      title: 'font_size'.tr(),
                      hintText: 'font_size_hint'.tr(),
                    );
                    // showColorPicker(context, _quoteColor, (Color color) {
                    setState(() {
                      Utils.setDouble('write_font_size',
                          double.parse(_fontSize.toString()));
                    });
                    // });
                  },
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  trailing: Switch(

                    value: _switchValue1,
                    onChanged: (value) => setState(() {
                      _switchValue1 = value;
                      Utils.setBool('write_view_count', value);
                    }),
                  ),
                  title: Text('view_word_count'.tr()),
                  leading: Icon(
                    Icons.publish_outlined,
                    size: 20,
                  ),
                  onTap: () {},
                ),
                ExpansionTile(
                  trailing: Text(
                    _autoTimes.toString() + 's',
                    style: TextStyle(fontSize: 16),
                  ),
                  collapsedBackgroundColor: Colors.transparent,
                  children: [
                    ListTile(
                      title: const Text('5s'),
                      onTap: () {
                        setState(() {
                          _autoTimes = 5;
                          Utils.setInt('write_auto_times', 5);
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('10s'),
                      onTap: () {
                        setState(() {
                          _autoTimes = 10;
                          Utils.setInt('write_auto_times', 10);
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('30s'),
                      onTap: () {
                        setState(() {
                          _autoTimes = 30;
                          Utils.setInt('write_auto_times', 30);
                        });
                      },
                    )
                  ],
                  title: Text('auto_save_interval'.tr()),
                  leading: Icon(
                    Icons.info_outlined,
                    size: 20,
                  ),
                ),
                ExpansionTile(
                  trailing: Text(
                    _imageQuality.toString(),
                    style: TextStyle(fontSize: 16),
                  ),
                  collapsedBackgroundColor: Colors.transparent,
                  children: [
                    ListTile(
                      title: const Text(' 60%'),
                      onTap: () {
                        setState(() {
                          _imageQuality = 60;
                          Utils.setInt('write_image_quality', 60);
                        });
                      },
                    ),
                    ListTile(
                      title: const Text(' 80%'),
                      onTap: () {
                        setState(() {
                          _imageQuality = 80;
                          Utils.setInt('write_image_quality', 80);
                        });
                      },
                    ),
                    ListTile(
                      title: const Text(' 100%'),
                      onTap: () {
                        setState(() {
                          _imageQuality = 100;
                          Utils.setInt('write_image_quality', 100);
                        });
                      },
                    )
                  ],
                  title: Text('updata_image_quality'.tr()),
                  leading: Icon(
                    Icons.image,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // 功能列表：关于我们（占位）
        ],
      ),
    );
  }
}
