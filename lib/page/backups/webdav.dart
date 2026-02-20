// WebDAV图床实现

import 'dart:convert';
import 'dart:io';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';
import 'package:path/path.dart' as path;

class Webdav {
  bool isValid() {
    // TODO: implement isValid
    return _validateConfig();
  }
  // 从本地存储读取配置
  static String get server => Utils.getBackupsConfig()['local']!;
  static String get username => Utils.getBackupsConfig()['user']!;
  static String get password => Utils.getBackupsConfig()['pass']!;
  static String get basePath => Utils.getBackupsConfig()['path']!;
  // 验证配置完整性
  bool _validateConfig() {
    if (server.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        basePath.isEmpty) {
      return false;
    }
    return true;
  }
  // 创建并初始化WebDAV客户端
  // 创建并初始化WebDAV客户端（1.2.1版本专属）
  static Future<webdav.Client> _createClient() async {
    // 1.2.1版本通过newClient静态方法创建客户端
    final client = await webdav.newClient(
      server,
      user: username,
      password: password,
    );
    // 配置超时（1.2.1版本通过dio直接配置）
    client..setHeaders({'accept-charset': 'utf-8'});
    client..setConnectTimeout(8000);
    client..setSendTimeout(8000);
    client..setReceiveTimeout(8000);

    return client;
  }
  /// 1. 获取图片列表（适配1.2.1版本FileEntity）
  // Future<List<WebDavImageModel>> getImageList() async {
  //   final client = await _createClient();
  //   final List<WebDavImageModel> imageList = [];
  //   try {
  //     // 1.2.1版本用readDir列出目录文件
  //     // 过滤图片文件
  //     var response = await client.readDir(basePath);
  //     for (var item in response) {
  //       final fullRemotePath = path.join(basePath, item.name);
  //       final downloadUrl = _buildDownloadUrl(fullRemotePath);

  //       imageList.add(WebDavImageModel(
  //         name: item.name.toString(),
  //         downloadUrl: downloadUrl,
  //         path: fullRemotePath,
  //         size: item.size ?? 0, // 1.2.1版本size可能为null
  //       ));
  //       //throw Exception("WebDAV获取列表失败：${imageList[0].downloadUrl}");
  //     }
  //     return imageList;
  //   } catch (e) {
  //     throw Exception("WebDAV获取列表失败：$e");
  //   } finally {}
  // }

  /// 2. 上传图片（适配1.2.1版本writeFromFile）

  static Future<bool> uploadFile(File file) async {
    final client = await _createClient();
    try {
      // 生成唯一文件名
      final appDocDir = await FileUtils.getAppDocDir();
      final folderPath = path.join(appDocDir.path, "diary");
      final relativePath = path.relative(file.path, from: folderPath);
      final remotePath = path.join(basePath, relativePath);
      // 1.2.1版本上传文件（writeFromFile参数不同）
      await client.writeFromFile(
        file.path,
        remotePath,
      );
      // 手动构建下载链接
      return true;
    } catch (e) {
      return false;
      // throw Exception("WebDAV上传失败：$e");
    } finally {}
  }

  /// 3. 删除（适配1.2.1版本remove）

  Future<bool> deleteFile(File file) async {
    final client = await _createClient();
    try {
      // 1.2.1版本删除文件
      await client.remove(file.path);
      return true;
    } catch (e) {
      throw Exception("WebDAV删除失败：$e");
    } finally {}
  }

  /// 手动构建下载链接（替代1.2.1版本缺失的resolvePath）

  @override
  Future<Map<File, bool>> uploadFilesBatch(
      {required List<File>? files,
      int maxConcurrent = 3,
      Duration batchDelay = const Duration(milliseconds: 500),
      Function(int uploaded, int total)? onProgress,
      Function(File file, String error)? onError}) async {
    if (files == null || files.isEmpty) {
      throw Exception("请选择要上传的图片");
    }

    final successfulUploads = <File, bool>{};
    int completedCount = 0;
    final totalCount = files.length;
    // 遍历所有文件进行上传

    final uploadFutures = files.map((imageFile) async {
      bool isSuccess = false;
      try {
        await Future.delayed(batchDelay); // 增加批次间隔
        final url = await uploadFile(imageFile);
        isSuccess = true;
        successfulUploads[imageFile] = url;
      } catch (e) {
        isSuccess = false;
        final errorMsg = "文件${imageFile.path}上传失败：$e";
        onError?.call(imageFile, errorMsg);
      } finally {
        completedCount++;
        if (isSuccess) {
          onProgress?.call(completedCount, totalCount);
        }
        // 更新进度
      }
    }).toList();
    // 等待所有上传任务完成
    await Future.wait(uploadFutures);
    return successfulUploads;
  }
}
