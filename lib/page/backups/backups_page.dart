import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/page/backups/webdav.dart';
import 'package:editor/provider.dart';
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
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BackupsPage extends StatefulWidget {
  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  // 显示错误提示弹窗
  Map<String, dynamic> config = Utils.getBackupsConfig();
  String _user = "";
  String _local = "";
  String _pass = "";
  String _path = "";

  bool _switchValue1 = false;
  @override
  void initState() {
    super.initState();
    _switchValue1 = config['is_auto']!;
    _path = config['path'] != null ? config['path'] : "";

    _user = config['user'] != null ? config['user'] : "";
    _local = config['local'] != null ? config['local'] : "";
    _pass = config['pass'] != null ? config['pass'] : "";

    // 计算缓存大小
  }

  /// 递归遍历目录下所有文件（返回所有文件的File对象列表）
  Future<List<File>> listAllFilesInDir(Directory dir) async {
    List<File> allFiles = [];

    try {
      // 遍历当前目录的所有实体（文件+文件夹）
      final entities = dir.list(recursive: true, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) {
          // 是文件则加入列表
          allFiles.add(entity);
        } else if (entity is Directory) {
          // 是文件夹则递归遍历（list的recursive: true已包含此逻辑，此处仅作说明）
          continue;
        }
      }
    } catch (e) {
      print("遍历目录失败：${dir.path}，错误：$e");
    }

    return allFiles;
  }

  /// 批量上传指定目录下的所有文件到 WebDAV
  Future<Map<String, dynamic>> batchUploadFiles() async {
    try {
      // 1. 获取应用文档目录
      final appDir = await FileUtils.getAppDocDir();
      final folderPath = path.join(appDir.path, "diary");
      if (!await Directory(folderPath).exists()) {
        await Directory(folderPath).create(recursive: true);
        return {"success": false, "successCount": 0, "totalCount": 0};
      }
      // 2. 遍历目录下所有文件
      final allFiles = await listAllFilesInDir(Directory(folderPath));
      if (allFiles.isEmpty) {
        return {"success": false, "successCount": 0, "totalCount": 0};
      }
      // 3. 批量上传（串行上传，也可改为并行：使用 Future.wait）
      int successCount = 0;
      for (final file in allFiles) {
        final isSuccess = await Webdav.uploadFile(file);
        if (isSuccess) {
          successCount++;
        }
      }

      print("批量上传完成：成功 $successCount/${allFiles.length} 个文件");
      return {
        "success": true,
        "successCount": successCount,
        "totalCount": allFiles.length
      };
    } catch (e) {
      print("批量上传失败，错误：$e");
      return {"success": false, "successCount": 0, "totalCount": 0};
    }
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
                  Utils.saveBackupsConfig(
                    isAutoBackups: _switchValue1,
                    local: controller.text,
                    user: _user,
                    pass: _pass,
                    path: _path,
                  );
                  setState(() {
                    _local = controller.text;
                  });
                  break;
                case 1:
                  Utils.saveBackupsConfig(
                    isAutoBackups: _switchValue1,
                    local: _local,
                    user: controller.text,
                    pass: _pass,
                    path: _path,
                  );
                  setState(() {
                    _user = controller.text;
                  });
                  // 新建图片文件
                  break;
                case 2:
                  Utils.saveBackupsConfig(
                    isAutoBackups: _switchValue1,
                    local: _local,
                    user: _user,
                    pass: controller.text,
                    path: _path,
                  );
                  setState(() {
                    _pass = controller.text;
                  });
                  // 提交文件
                  break;
                case 3:
                  Utils.saveBackupsConfig(
                    isAutoBackups: _switchValue1,
                    local: _local,
                    user: _user,
                    pass: _pass,
                    path: controller.text,
                  );
                  setState(() {
                    _path = controller.text;
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

        title: Text('backups_and_sync'.tr()),
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
                  subtitle: Text(
                    'backup_local_hint'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('backup_to_local'.tr()),
                  leading: Icon(
                    Icons.folder_zip,
                    size: 20,
                  ),
                  onTap: () async {
                    // 1. 压缩 + 导出示例
                    final hasPermission =
                        await FileUtils.requestStoragePermissions();
                    if (!hasPermission) {
                      // 没有权限，提示用户去设置开启
                      Utils.showToast(context, "toast_premission_denied".tr());
                      return;
                    }

                    // 1. 选择自定义文件夹
                    final Directory? selectedFolder =
                        await FileUtils.selectCustomFolder();
                    if (selectedFolder == null) {
                      Utils.showToast(context, "toast_cancel_backup".tr());
                      return;
                    }
                    DialogWidget.show(context: context);
                    try {
                      Map<String, dynamic> zipFile =
                          await FileUtils.compressAppDocToZip();
                      if (zipFile["success"]) {
                        Utils.showToast(context, "toast_compress".tr());
                        try {
                          await FileUtils.exportZipFile(
                              zipFile["zipFile"], selectedFolder.path);
                          DialogWidget.dismiss(context);
                          Utils.showToast(context, "toast_export_success".tr());
                        } catch (e) {
                          Utils.showToast(context, "toast_export_failed".tr());
                        }
                      } else {
                        Utils.showToast(context, zipFile["message"]);
                      }
                    } catch (e) {
                      Utils.showToast(context, "toast_compress_failed".tr());
                    }
                  },
                ),
                ListTile(
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                  subtitle: Text(
                    'import_file_hint'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('import_file'.tr()),
                  leading: Icon(
                    Icons.import_export_rounded,
                    size: 20,
                  ),
                  onTap: () async {
                    // 1. 压缩 + 导出示例
                    DialogWidget.show(context: context);
                    try {
                      final result = await FileUtils.importAndExtractZip();
                      Utils.showToast(
                          context, 'import_success'.tr() + '${result}文件');
                      Provider.of<GitProvider>(context, listen: false)
                          .refresh();
                      DialogWidget.dismiss(context);
                    } catch (e) {
                      Utils.showToast(context, 'import_failed'.tr());
                      DialogWidget.dismiss(context);
                    }
                  },
                ),
                ListTile(
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                  subtitle: Text(
                    'import_markdown_hint'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('import_markdown_file'.tr()),
                  leading: Icon(
                    Icons.self_improvement_outlined,
                    size: 20,
                  ),
                  onTap: () async {
                    // 1. 压缩 + 导出示例
                    DialogWidget.show(context: context);
                    try {
                      final result = await FileUtils.importMarkdown();
                      if (result) {
                        Utils.showToast(context, 'import_success'.tr());
                        Provider.of<GitProvider>(context, listen: false)
                            .refresh();
                        DialogWidget.dismiss(context);
                      } else {
                        Utils.showToast(context, 'import_failed'.tr());
                        DialogWidget.dismiss(context);
                      }
                    } catch (e) {
                      Utils.showToast(context, 'import_failed'.tr());
                      DialogWidget.dismiss(context);
                    }
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
                  trailing: Switch(

                    onChanged: (value) =>{
                      setState(() {
                        Utils.saveBackupsConfig(
                          isAutoBackups: value,
                          local: config['local'],
                          user: config['user'],
                          pass: config['pass'],
                          path: config['path'],
                        );
                        _switchValue1 = value;
                      })
                    },
                    value: _switchValue1,

                  ),
                  title: Text('auto_sync'.tr()),
                  leading: Icon(
                    Icons.backup,
                    size: 20,
                  ),
                  onTap: () {},
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
                    _local,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('backup_service_address'.tr()),
                  leading: Icon(
                    Icons.web,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['local']!,
                        title: 'backup_service_address'.tr(),
                        hintText: 'backup_service_address_hint'.tr(),
                        type: 0);
                  },
                ),
                ListTile(
                  subtitle: Text(
                    _user,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('backup_username'.tr()),
                  leading: Icon(
                    Icons.account_circle_sharp,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['user']!,
                        title: 'backup_username'.tr(),
                        hintText: 'backup_username_hint'.tr(),
                        type: 1);
                  },
                ),
                ListTile(
                  subtitle: Text(
                    _pass,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('backup_password'.tr()),
                  leading: Icon(
                    Icons.lock,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['pass']!,
                        title: 'backup_password'.tr(),
                        hintText: 'backup_password_hint'.tr(),
                        type: 2);
                  },
                ),
                ListTile(
                  subtitle: Text(
                    _path,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  title: Text('backup_path'.tr()),
                  leading: Icon(
                    Icons.filter_drama_sharp,
                    size: 20,
                  ),
                  onTap: () {
                    _showDialog(
                        defaultValue: config['path']!,
                        title: 'backup_path'.tr(),
                        hintText: 'backup_path_hint'.tr(),
                        type: 3);
                  },
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              // 并行上传示例（替换批量上传的for循环）
              // 执行批量上传
              DialogWidget.show(context: context);
              try {
                final result = await batchUploadFiles();
                if (result["success"]) {
                  setState(() {
                    DialogWidget.dismiss(context);
                  });
                  Utils.showToast(
                    context,
                    "sync_success_count".tr().replaceAll(
                        "{count}", result["successCount"].toString()),
                  );
                } else {
                  Utils.showToast(
                    context,
                    "sync_failed_count".tr().replaceAll(
                        "{count}", result["successCount"].toString()),
                  );
                }
              } catch (e) {
                Utils.showToast(
                  context,
                  "sync_failed".tr(),
                );
              }
            },
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Text(
                      'sync_all'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )

          // 功能列表：关于我们（占位）
        ],
      ),
    );
  }
}
