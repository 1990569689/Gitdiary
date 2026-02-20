import 'dart:io';
import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gallery_saver/gallery_saver.dart';

class FileUtils {
  // 获取应用私有文档目录
  static Future<Directory> getAppDocDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      // Windows 可选：也可使用 getApplicationSupportDirectory()（更隐蔽）
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isMacOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      // Linux/Web（Web 需特殊处理：localStorage 替代文件）
      return await getApplicationDocumentsDirectory();
    }
  }

  /// 权限申请：适配 Android/iOS 相册权限
  static Future<bool> requestPhotoPermission() async {
    Permission permission;
    if (Platform.isAndroid) {
      // Android 13+ 用 photos 权限，旧版本用 storage
      permission = Platform.version.contains('13')
          ? Permission.photos
          : Permission.storage;
    } else if (Platform.isIOS) {
      // iOS 14+ 推荐用 photosAddOnly（仅添加权限，更精细）
      permission = Permission.photosAddOnly;
    } else {
      return false;
    }

    final status = await permission.status;
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      // 首次请求权限
      final result = await permission.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      // 权限被永久拒绝，引导用户去设置开启
      await openAppSettings();
      return false;
    }
    return false;
  }

  /// 保存网络图片到相册
  static Future<bool> saveNetworkImageToGallery(String imageUrl) async {
    // 先申请权限
    final hasPermission = await requestPhotoPermission();
    if (!hasPermission) return false;

    try {
      // 1. 下载网络图片到临时目录
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      await dio.download(imageUrl, tempPath);
      print('📥 开始下载图片：$imageUrl → $tempPath');
      // 2. 保存到相册
      final result = await GallerySaver.saveImage(tempPath);
      return result ?? false;
      // return false;
    } catch (e) {
      throw Exception('保存网络图片失败：$e');
      return false;
    }
  }

  /// 保存本地图片到相册
  Future<bool> saveLocalImageToGallery(String localImagePath) async {
    final hasPermission = await requestPhotoPermission();
    if (!hasPermission) return false;

    try {
      final result = await GallerySaver.saveImage(localImagePath);
      return result ?? false;
      // return false;
    } catch (e) {
      print('保存本地图片失败：$e');
      return false;
    }
  }

  // 获取图片缓存目录（用于存储插入的图片）
  static Future<Directory> getImageCacheDir() async {
    final appDir = await getAppDocDir();
    final imageDir = Directory(path.join(appDir.path, 'image_cache'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  // 申请存储权限（适配安卓/iOS）
  static Future<bool> requestStoragePermission() async {
    Permission permission = Platform.isAndroid
        ? (await _isAndroid13Plus() ? Permission.photos : Permission.storage)
        : Permission.storage;

    final status = await permission.request();
    return status.isGranted;
  }

  // 判断是否为Android 13+
  static Future<bool> _isAndroid13Plus() async {
    if (!Platform.isAndroid) return false;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }

  static Future<AndroidDeviceInfo> get version async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info;
  }

  //请求存储权限
  static Future<bool> requestStoragePermissions() async {
    Permission permission;
    if (Platform.isAndroid) {
      if (await _isAndroid13Plus()) {
        permission = Permission.photos; // Android 13+ 用photos权限
      } else {
        permission = Permission.storage;
      }
    } else {
      permission = Permission.storage; // iOS
    }

    final status = await permission.request();
    return status.isGranted;
  }

  // 创建文件夹
  static Future<bool> createFolder(String folderName) async {
    try {
      final appDir = await getAppDocDir();
      final folderPath = path.join(appDir.path, folderName);
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      print('创建文件夹失败：$e');
      return false;
    }
  }

  // 创建新的MD文件
  static Future<File?> createMdFile(String fileName,
      {String? parentPath}) async {
    try {
      final appDir = await getAppDocDir();
      final filePath = parentPath != null
          ? path.join(parentPath, '$fileName.md')
          : path.join(appDir.path, '$fileName.md');
      final file = File(filePath);
      if (!await file.exists()) {
        await file.create(recursive: true);
        // 关键：创建成功后，保存创建时间到数据库
        final createTime = DateTime.now();
        await DatabaseHelper().insertRecord(filePath, createTime);
        await file.writeAsString('');
        return file;
      }

      return null;
    } catch (e) {
      print('创建MD文件失败：$e');
      return null;
    }
  }

  static Future<File?> createHtmlFile(String fileName,
      {String? parentPath}) async {
    try {
      final appDir = await getAppDocDir();
      final filePath = parentPath != null
          ? path.join(parentPath, '$fileName.gtx')
          : path.join(appDir.path, '$fileName.gtx');
      final file = File(filePath);
      if (!await file.exists()) {
        await file.create(recursive: true);
        // 关键：创建成功后，保存创建时间到数据库
        final createTime = DateTime.now();
        await DatabaseHelper().insertRecord(filePath, createTime);
        await file.writeAsString('');
        return file;
      }

      return null;
    } catch (e) {
      print('创建MD文件失败：$e');
      return null;
    }
  }


  static Future<bool> saveHtmlFile(String filePath, String content) async {
    try {
      await File(filePath).writeAsString(content);
      // final createTime = DateTime.now();
      // await DatabaseHelper()
      //     .insertRecord(filePath.split('/').last.split('.').first, createTime);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 读取MD文件内容
  static Future<String> readHtmlFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists() ? await file.readAsString() : '';
    } catch (e) {
      return '';
    }
  }

  // 保存MD文件内容
  static Future<bool> saveMdFile(String filePath, String content) async {
    try {
      await File(filePath).writeAsString(content);
      // final createTime = DateTime.now();
      // await DatabaseHelper()
      //     .insertRecord(filePath.split('/').last.split('.').first, createTime);
      return true;
    } catch (e) {
      print('保存MD文件失败：$e');
      return false;
    }
  }

  // 读取MD文件内容
  static Future<String> readMdFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists() ? await file.readAsString() : '';
    } catch (e) {
      print('读取MD文件失败：$e');
      return '';
    }
  }

  // 获取目录下的所有文件/文件夹
  static Future<List<FileSystemEntity>> getFiles(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      return await dir.exists() ? dir.listSync().toList() : [];
    } catch (e) {
      print('获取文件列表失败：$e');
      return [];
    }
  }

  // 加载本地文件列表（仅MD文件和文件夹）
  static Future<List<FileSystemEntity>> loadFiles() async {
    try {
      final docDirs = await getAppDocDir();
      final dir = Directory(docDirs.path);
      final entities = await dir.list().toList();
      // 按文件夹优先、名称排序
      entities.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
      return entities;
    } catch (e) {
      print('加载文件列表失败：$e');
      return [];
    }
  }

  static Future<bool?> saveModelToDir(
      String tempFilePath, String title, String content) async {
    final appDir = await getAppDocDir();

    if (await File(tempFilePath) is File) {
      if (await File(tempFilePath).exists()) {
        if (tempFilePath.endsWith(".gtx")) {
          final folderPath = path.join(appDir.path, "gtx_model");
          try {
            final folder = Directory(folderPath);
            if (!await folder.exists()) {
              await folder.create(recursive: true);
            }
            final targetPath = folder.path + "/" + title + ".mgtx";
            await File(tempFilePath).copy(targetPath);
            return true;
          } catch (e) {
            return false;
          }
        } else if (tempFilePath.endsWith(".md")) {
          final folderPath = path.join(appDir.path, "md_model");
          try {
            final folder = Directory(folderPath);
            if (!await folder.exists()) {
              await folder.create(recursive: true);
            }
            final targetPath = folder.path + "/" + title + ".mmd";
            await File(tempFilePath).copy(targetPath);
            return true;
          } catch (e) {
            return false;
          }
        }
      } else {
        // try {
        //   final filePath = path.join(folderPath, '$title.mgtx');
        //   final file = File(filePath);
        //   if (!await file.exists()) {
        //     await file.create(recursive: true);
        //     await file.writeAsString('');
        //     return file;
        //   }
        //   return null;
        // } catch (e) {
        //   print('创建MD文件失败：$e');
        //   return null;
        // }
      }
    }
  }

  static Future<File?> saveImageToDir(dynamic tempFile) async {
    if (tempFile is XFile) {
      try {
        final appDir = await getAppDocDir();
        final folderPath = path.join(appDir.path, "image");
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        final targetPath = folder.path + "/" + tempFile.name;
        final File targeFile = File(targetPath);
        await tempFile.saveTo(targetPath);
        return targeFile;
      } catch (e) {
        return null;
      }
    } else if (tempFile is FilePickerResult) {
      try {
        final appDir = await getAppDocDir();
        final folderPath = path.join(appDir.path, "image");
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        final targetPath = folder.path + "/" + tempFile.files.first!.name;
        final File targeFile = File(targetPath);
        await tempFile.files.first.xFile.saveTo(targetPath);
        return targeFile;
      } catch (e) {
        return null;
      }
    }
  }

  // 保存图片到缓存目录（用于编辑器插入图片）
  static Future<String?> saveImageToCache(File imageFile) async {
    try {
      final imageDir = await getImageCacheDir();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final targetFile = File(path.join(imageDir.path, fileName));
      await imageFile.copy(targetFile.path);
      return targetFile.path;
    } catch (e) {
      print('保存图片失败：$e');
      return null;
    }
  }

//  static Future<List<File>> listAllFilesInDir(Directory dir) async {
//     List<File> allFiles = [];

//     try {
//       // 遍历当前目录的所有实体（文件+文件夹）
//       final entities = dir.list(recursive: true, followLinks: false);
//       await for (final entity in entities) {
//         if (entity is File) {
//           // 是文件则加入列表
//           allFiles.add(entity);
//         } else if (entity is Directory) {
//           // 是文件夹则递归遍历（list的recursive: true已包含此逻辑，此处仅作说明）
//           continue;
//         }
//       }
//     } catch (e) {
//       print("遍历目录失败：${dir.path}，错误：$e");
//     }

//     return allFiles;
//   }
  /// 步骤1：选择本地自定义文件夹（跨平台）
  static Future<Directory?> selectCustomFolder() async {
    // 申请文件权限（Android/iOS 必需）
    final hasPermission = await requestFilePermission();
    if (!hasPermission) {
      print("文件夹选择失败：文件权限未授权");
      return null;
    }

    // 调用文件选择器，选择文件夹
    final String? selectedDirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "请选择要导出的文件夹", // 对话框标题（Windows/macOS 生效）
      lockParentWindow: true, // Windows：锁定父窗口，避免多窗口混乱
    );

    if (selectedDirPath == null || selectedDirPath.isEmpty) {
      print("用户取消了文件夹选择");
      return null;
    }

    final Directory selectedDir = Directory(selectedDirPath);
    if (!await selectedDir.exists()) {
      print("选择的文件夹不存在：$selectedDirPath");
      return null;
    }

    print("已选择文件夹：${selectedDir.path}");
    return selectedDir;
  }

// ==================== ZIP 压缩 + 导出功能 ====================
//   / 压缩应用文档目录为 ZIP 文件（先保存到临时目录，再导出）
  static Future<Map<String, dynamic>> compressAppDocToZip() async {
    try {
      // 1. 获取应用文档目录和临时目录
      final appDocDir = await getAppDocDir();
      final folderPath = path.join(appDocDir.path, "diary");
      final tempDir = await getTemporaryDirectory();
      // ZIP 文件名：app_doc_时间戳.zip
      final zipFileName =
          "app_doc_${DateTime.now().millisecondsSinceEpoch}.zip";
      final zipTempPath = path.join(tempDir.path, zipFileName);
      // 2. 遍历应用文档目录下所有文件（保留目录结构）
      final files = await listAllFilesInDir(Directory(folderPath));
      if (files.isEmpty) {
        print("应用文档目录无文件可压缩");
        return {"success": false, "message": "应用文档目录无文件可压缩"};
      }
      // 3. 初始化 ZIP 归档
      final archive = Archive();
      for (final file in files) {
        // 读取文件内容
        final fileBytes = await file.readAsBytes();
        // 计算文件在 ZIP 中的相对路径（保留目录结构）
        final relativePath = path.relative(file.path, from: folderPath);
        // 创建 ZIP 归档文件项
        final archiveFile = ArchiveFile(
          relativePath,
          fileBytes.length,
          fileBytes,
        );
        // 设置压缩格式（DEFLATE 压缩率更高）
        ;
        archive.addFile(archiveFile);
      }
      // 4. 生成 ZIP 文件并保存到临时目录
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        print("ZIP 压缩失败：未生成字节数据");
        return {"success": false, "message": "ZIP 压缩失败：未生成字节数据"};
      }
      final zipFile = File(zipTempPath);
      await zipFile.writeAsBytes(zipBytes);

      print("ZIP 压缩完成：${zipFile.path}");
      return {"success": true, "zipFile": zipFile};
    } catch (e) {
      print("压缩失败：$e");
      return {"success": false, "message": "压缩失败：$e"};
    }
  }

  /// 申请文件访问权限（Android/iOS 必需）
  static Future<bool> requestFilePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 申请媒体文件权限，低版本申请存储权限
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted;
    }
    // Windows/macOS/Linux 无需显式申请
    return true;
  }

  /// 导出 ZIP 文件到本地自定义位置（调用系统保存对话框）
  static Future<bool> exportZipFile(File zipFile, String customSavePath) async {
    if (!await zipFile.exists()) {
      print("ZIP 文件不存在：${zipFile.path}");
      return false;
    }

    // 申请权限（Android/iOS）
    final hasPermission = await requestFilePermission();
    if (!hasPermission) {
      print("文件权限申请失败，无法导出");
      return false;
    }

    try {
      // ========== 步骤3：写入自定义路径 ==========
      final customFile = File(customSavePath +
          "/Gitdiary_Backup_${DateTime.now().millisecondsSinceEpoch}.zip");
      // 确保父目录存在
      await customFile.parent.create(recursive: true);
      // 写入Zip字节数据
      await customFile.writeAsBytes(zipFile.readAsBytesSync());
      return true;
      // 读取 ZIP 文件字节
      // final zipBytes = await zipFile.readAsBytes();
      // // 调用系统保存对话框，让用户选择保存位置
      // final result = await FileSaver.instance.saveFile(

      //   name: path.basename(zipFile.path), // 保留原文件名
      //   bytes: Uint8List.fromList(zipBytes),
      //   ext: "zip",
      //   mimeType: MimeType.zip,
      // );

      // if (result != null) {
      //   print("ZIP 文件导出成功" + result);
      //   return true;
      // } else {
      //   print("用户取消了文件保存");
      //   return false;
      // }
    } catch (e) {
      print("ZIP 导出失败：$e");
      return false;
    }
  }

// ==================== ZIP 导入 + 解压功能 ====================
// / 选择本地 ZIP 文件并导入（解压）到应用文档目录
  static Future<int> importAndExtractZip() async {
    // 1. 申请权限（Android/iOS）
    final hasPermission = await requestFilePermission();
    if (!hasPermission) {
      print("文件权限申请失败，无法导入");
      return 0;
    }

    // 2. 打开文件选择器，仅允许选择 ZIP 文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["zip"],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      print("未选择任何 ZIP 文件");
      return 0;
    }

    // 3. 获取选中的 ZIP 文件路径
    final zipFilePath = result.files.first.path;
    if (zipFilePath == null) {
      print("ZIP 文件路径为空");
      return 0;
    }
    final zipFile = File(zipFilePath);

    try {
      // 4. 读取并解压 ZIP 文件
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      if (archive.files.isEmpty) {
        print("ZIP 文件为空，无需解压");
        return 0;
      }

      // 5. 获取应用文档目录（解压目标目录）
      final appDocDir = await getAppDocDir();
      final folderPath = path.join(appDocDir.path, "diary");
      int successCount = 0;

      // 6. 遍历归档文件，逐个解压
      for (final archiveFile in archive.files) {
        if (archiveFile.isFile) {
          // 跳过文件夹（自动创建）
          // 构建解压后的文件路径
          final extractPath = path.join(folderPath, archiveFile.name);
          // 创建父目录（如果不存在）
          final extractDir = Directory(path.dirname(extractPath));
          await extractDir.create(recursive: true);

          // 写入文件内容
          final file = File(extractPath);
          await file.writeAsBytes(archiveFile.content as List<int>);
          successCount++;
          print("解压成功：$extractPath");
        }
      }

      print("ZIP 解压完成：成功解压 $successCount 个文件");
      return successCount;
    } catch (e) {
      print("导入/解压失败：$e");
      return 0;
    }
  }

  // 核心方法：从设备选择.md文件并复制到文档目录
  static Future<bool> importMarkdown() async {
    try {
      // 1. 打开文件选择器，仅允许选择.md文件
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'gtx'], // 仅允许md格式
        allowMultiple: false, // 单次选一个文件
      );

      if (result == null) {
        return false;
      }

      // 2. 获取选中的源文件路径
      final PlatformFile sourceFile = result.files.first;
      final File originalFile = File(sourceFile.path!);

      // 3. 获取应用文档目录，拼接目标路径
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final folderPath = path.join(appDocDir.path, "diary");
      final String targetFilePath = path.join(
        folderPath,
        sourceFile.name, // 保留原文件名
      );
      final File targetFile = File(targetFilePath);

      // 4. 复制文件到目标目录
      await originalFile.copy(targetFilePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 辅助函数：递归遍历目录下所有文件（保留原逻辑）
  static Future<List<File>> listAllFilesInDir(Directory dir) async {
    List<File> allFiles = [];
    try {
      final entities = dir.list(recursive: true, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) allFiles.add(entity);
      }
    } catch (e) {
      print("遍历目录失败：$e");
    }
    return allFiles;
  }
}
