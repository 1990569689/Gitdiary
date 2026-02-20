import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/page/backups/webdav.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:editor/widget/dialog_widget.dart';
import 'package:editor/widget/switch_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // 显示错误提示弹窗
  Map<String, dynamic> config = Utils.getAiConfig();
  String _name = "not_set".tr();
  String _api = "not_set".tr();
  String _model = "not_set".tr();
  String _token = "not_set".tr();

  @override
  void initState() {
    super.initState();
    _name = config['name'] != null ? config['name'] : "";
    _api = config['api'] != null ? config['api'] : "";
    _model = config['model'] != null ? config['model'] : "";
    _token = config['token'] != null ? config['token'] : "";

    // 计算缓存大小
  }

  // 新建MD文件弹窗
  Future<void> _showDialog({
    required String defaultValue,
    required String title,
    required String hintText,
    required int type,
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
              switch (type) {
                case 0:
                  // 新建MD文件
                  Utils.saveAiConfig(
                    name: controller.text,
                    api: _api,
                    token: _token,
                    model: _model,
                  );
                  setState(() {
                    _name = controller.text;
                  });
                  break;
                case 1:
                  Utils.saveAiConfig(
                    name: _name,
                    api: controller.text,
                    token: _token,
                    model: _model,
                  );
                  setState(() {
                    _api = controller.text;
                  });
                  // 新建图片文件
                  break;
                case 2:
                  Utils.saveAiConfig(
                    name: _name,
                    api: _api,
                    token: controller.text,
                    model: _model,
                  );
                  setState(() {
                    _token = controller.text;
                  });
                  // 提交文件
                  break;
                case 3:
                  Utils.saveAiConfig(
                    name: _name,
                    api: _api,
                    token: _token,
                    model: controller.text,
                  );
                  setState(() {
                    _model = controller.text;
                  });
                  // 提交文件
                  break;
              }
              Navigator.pop(context);
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [],
        flexibleSpace: Container(
          width: double.infinity,
        ),

        title: Text('large_model_settings'.tr()),
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
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                  subtitle: Text(_name),
                  title: Text('large_model_service_name'.tr()),
                  leading: Icon(
                    Icons.crisis_alert_outlined,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: _name!,
                        title: 'large_model_service_name'.tr(),
                        hintText: 'large_model_service_name_hint'.tr(),
                        type: 0);
                  },
                ),
              ],
            ),
          ),
          // 顶部个人信息卡片
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  subtitle: Text(
                    _api,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('large_model_api_base_url'.tr()),
                  leading: Icon(
                    Icons.backup,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: _api!,
                        title: 'large_model_api_base_url'.tr(),
                        hintText: 'large_model_api_base_url_hint'.tr(),
                        type: 1);
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
                  subtitle: Text(
                    _token,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('large_model_api_key'.tr()),
                  leading: Icon(
                    Icons.lock,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: _token!,
                        title: 'large_model_api_key'.tr(),
                        hintText: 'large_model_api_key_hint'.tr(),
                        type: 2);
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
                  subtitle: Text(
                    _model,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('large_model_api_model'.tr()),
                  leading: Icon(
                    Icons.mode_edit_outline_outlined,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: _model!,
                        title: 'large_model_api_model'.tr(),
                        hintText: 'large_model_api_model_hint'.tr(),
                        type: 3);
                  },
                ),
              ],
            ),
          ),
          // GestureDetector(
          //   onTap: () async {
          //     // 并行上传示例（替换批量上传的for循环）
          //     // 执行批量上传
          //     DialogWidget.show(context: context);
          //   },
          //   child: Card(
          //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //     elevation: 0,
          //     child: Column(
          //       children: [
          //         Container(
          //           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          //           child: Text(
          //             '测试',
          //             style: TextStyle(
          //               fontSize: 16,
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // )

          // 功能列表：关于我们（占位）
        ],
      ),
    );
  }
}
