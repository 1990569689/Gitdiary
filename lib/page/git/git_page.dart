import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:editor/widget/switch_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class GitPage extends StatefulWidget {
  @override
  State<GitPage> createState() => _GitPageState();
}

class _GitPageState extends State<GitPage> {
  // 显示错误提示弹窗
  Map<String, dynamic> config = Utils.getGitConfig();
  bool _value = false;
  String _image = "";
  String _repo = "";
  String _branch = "";
  String _message = "";
  @override
  void initState() {
    super.initState();
    // 计算缓存大小
    //  'image': _prefs.getString('github_image_path') ?? 'images',
    //   'dialog': _prefs.getBool('github_is_dialog') ?? false,
    //   'repo': _prefs.getString('github_repo') ?? 'GitNotes',
    //   'message': _prefs.getString('github_message') ??
    //       'Update ${DateTime.now().toIso8601String()}',
    //   'branch': _prefs.getString('github_branch') ?? 'master',
    _image = config['image'] != null ? config['image'] : "";
    _repo = config['repo'] != null ? config['repo'] : "";
    _branch = config['branch'] != null ? config['branch'] : "";
    _message = config['message'] != null ? config['message'] : "";
    _value = config['dialog']!;
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
                  Utils.saveGitConfig(
                    isDialog: _value,
                    repo: controller.text,
                    branch: config['branch'],
                    message: config['message'],
                    imagePath: config['image'],
                  );
                  setState(() {
                    _repo = controller.text;
                  });
                  break;
                case 1:
                  Utils.saveGitConfig(
                    isDialog: _value,
                    repo: config['repo'],
                    branch: controller.text,
                    message: config['message'],
                    imagePath: config['image'],
                  );
                  setState(() {
                    _branch = controller.text;
                  });
                  // 新建图片文件
                  break;
                case 2:
                  Utils.saveGitConfig(
                    isDialog: _value,
                    repo: config['repo'],
                    branch: config['branch'],
                    message: controller.text,
                    imagePath: config['image'],
                  );
                  setState(() {
                    _message = controller.text;
                  });
                  // 提交文件
                  break;
                case 3:
                  Utils.saveGitConfig(
                    isDialog: _value,
                    repo: config['repo'],
                    branch: config['branch'],
                    message: config['message'],
                    imagePath: controller.text,
                  );
                  setState(() {
                    _image = controller.text;
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
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.search),
          //   onPressed: () {},
          // ),
        ],
        flexibleSpace: Container(
          width: double.infinity,
        ),

        title: Text('git_settings'.tr()),
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
          // 顶部个人信息卡片
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  trailing: Switch(

                    value: _value,
                    onChanged: (value) => setState(() {
                      _value = value;
                      Utils.saveGitConfig(
                        isDialog: value,
                        repo: config['repo'],
                        branch: config['branch'],
                        message: config['message'],
                        imagePath: config['image'],
                      );
                    }),
                  ),
                  title: Text('show_confirm_dialog'.tr()),
                  leading: Icon(
                    Icons.local_fire_department,
                    size: 20,
                  ),
                  onTap: () {},
                ),
                ListTile(
                  
                  title: Text('default_repo'.tr()),
                  subtitle: _repo != ''
                      ? Text(
                          _repo,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : Text(
                          'not_set  '.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['repo']!,
                        title: 'default_repo'.tr(),
                        hintText: 'default_repo_hint'.tr(),
                        type: 0);
                  },
                  leading: Icon(
                    Icons.warehouse,
                    size: 20,
                  ),
                ),
                ListTile(
                 
                  title: Text('default_branch'.tr()),
                  subtitle: _branch != ''
                      ? Text(
                          _branch,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : Text(
                          'not_set'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                  leading: Icon(
                    Icons.emoji_food_beverage_rounded,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['branch']!,
                        title: 'default_branch'.tr(),
                        hintText: 'default_branch_hint'.tr(),
                        type: 1);
                  },
                ),
                ListTile(
                
                  title: Text('default_commit_message'.tr()),
                  subtitle: _message != ''
                      ? Text(
                          _message,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : Text(
                          'not_set'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                  leading: Icon(
                    Icons.message,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['message']!,
                        title: 'default_commit_message'.tr(),
                        hintText: 'default_commit_message_hint'.tr(),
                        type: 2);
                  },
                ),
                ListTile(
                 
                  subtitle: _image != ''
                      ? Text(
                          _image,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : Text(
                          'not_set'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                  title: Text('default_commit_image'.tr()),
                  leading: Icon(
                    Icons.image,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['image']!,
                        title: 'default_commit_image'.tr(),
                        hintText: 'default_commit_image_hint'.tr(),
                        type: 3);
                  },
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
