import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/database.dart';
import 'package:editor/page/editor/markdown_edit_page.dart';
import 'package:editor/provider.dart';
import 'package:editor/rich/rich_edit_page.dart';
import 'package:editor/theme.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

// 定义视图类型枚举
enum ViewType {
  list, // 列表视图
  grid // 网格视图
}

class Home extends StatefulWidget {
  String title;
  Home({super.key, required this.title});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  late GitProvider _git;
  bool _canPop = true;
  String _currentDir = '';
  String _rootDir = '';
  List<FileSystemEntity> _originalFileList = []; // 原始文件列表（未过滤）
  List<FileSystemEntity> _filteredFileList = []; // 过滤后的文件列表（用于展示）
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
  final Set<dynamic> _selectedIds = {};
  bool _isEditMode = false;

  // 新增：视图切换相关
  ViewType _currentViewType = ViewType.list;
  // 新增：搜索相关
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  bool _isSearching = false;
  // 新增：文件内容缓存（避免重复读取）
  final Map<String, String> _fileContentCache = {};

  @override
  void initState() {
    super.initState();
    _git = Provider.of<GitProvider>(context, listen: false);
    _loadFiles();
    _git.addListener(_loadCurrentFiles);

    // 新增：监听搜索框输入
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _git.removeListener(_loadFiles);
    _searchController.dispose(); // 释放搜索控制器
    super.dispose();
  }

  // 新增：搜索文本变化监听
  void _onSearchTextChanged() {
    setState(() {
      _searchKeyword = _searchController.text.trim().toLowerCase();
    });
    _filterFiles(); // 过滤文件列表
  }

  // 新增：根据搜索关键词过滤文件
  Future<void> _filterFiles() async {
    if (_searchKeyword.isEmpty) {
      setState(() {
        _filteredFileList = List.from(_originalFileList);
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // 使用异步避免UI阻塞
    await Future.delayed(const Duration(milliseconds: 200), () async {
      final results = <FileSystemEntity>[];
      for (final entity in _originalFileList) {
        // 1. 搜索文件名
        final fileName = path.basename(entity.path).toLowerCase();
        if (fileName.contains(_searchKeyword)) {
          results.add(entity);
          continue;
        }
        // 2. 搜索文件内容（仅文本文件）
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.md', '.gtx'].contains(ext)) {
            try {
              // 读取文件内容（仅读取前2000字符，避免性能问题）
              String content = await _getFilePreviewContent(entity.path);
              if (content.toLowerCase().contains(_searchKeyword)) {
                results.add(entity);
              }
            } catch (e) {
              // 读取失败则跳过
              continue;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _filteredFileList = results;
          _isSearching = false;
        });
      }
    });
  }

  // 新增：获取文件预览内容（前100字符，处理换行）
  Future<String> _getFilePreviewContent(String filePath) async {
    // 优先从缓存读取
    if (_fileContentCache.containsKey(filePath)) {
      return _fileContentCache[filePath]!;
    }

    try {
      final file = File(filePath);
      // 只读取前2000字节，避免读取大文件
      final content = await file.readAsString();
      // 清理内容：移除换行符、多余空格，截取前100字符
      final previewContent = content
          .replaceAll(RegExp(r'\n|\r'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .substring(0, content.length > 100 ? 100 : content.length);

      // 存入缓存
      _fileContentCache[filePath] = previewContent;
      return previewContent;
    } catch (e) {
      return 'preview_unavailable'.tr(); // 预览不可用（需添加国际化）
    }
  }

  Future<void> _loadCurrentFiles() async {
    final appDir = await FileUtils.getAppDocDir();
    final folderPath = path.join(appDir.path, "diary");

    if (!await Directory(folderPath).exists()) {
      await Directory(folderPath).create(recursive: true);
    }

    _rootDir = folderPath;
    final targetDir = _currentDir ?? folderPath;
    final entities = await Directory(targetDir).list().toList();

    // 排序：文件夹优先，按名称升序
    entities.sort((a, b) {
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;
      return a.path.compareTo(b.path);
    });

    setState(() {
      _currentDir = targetDir;
      _originalFileList = entities;
      _fileContentCache.clear(); // 清空缓存
    });

    // 重新过滤文件
    _filterFiles();
  }

  // 修改：加载文件列表（区分原始列表和过滤列表）
  Future<void> _loadFiles({String? dirPath}) async {
    final appDir = await FileUtils.getAppDocDir();
    final folderPath = path.join(appDir.path, "diary");

    if (!await Directory(folderPath).exists()) {
      await Directory(folderPath).create(recursive: true);
    }

    _rootDir = folderPath;
    final targetDir = dirPath ?? folderPath;
    final entities = await Directory(targetDir).list().toList();

    // 排序：文件夹优先，按名称升序
    entities.sort((a, b) {
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;
      return a.path.compareTo(b.path);
    });

    setState(() {
      _currentDir = targetDir;
      _originalFileList = entities;
      _fileContentCache.clear(); // 清空缓存
    });

    // 重新过滤文件
    _filterFiles();
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
                await DatabaseHelper().updateRecord(
                    firstName: entity.path.split("/").last,
                    lastName: newPath.split("/").last);
                _loadFiles(dirPath: _currentDir);

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

  // 原有方法：选项对话框（保留）
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

  // 原有方法：获取修改时间（保留）
  Future<String> _getModifiedTime(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      return _dateFormatter.format(stat.modified);
    } catch (e) {
      return 'unknown_time'.tr();
    }
  }

  // 原有方法：新建文件夹（保留）
  Future<void> _showCreateFolderDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('new_folder'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'new_folder_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final folderName = controller.text.trim();
              if (folderName.isNotEmpty) {
                final success = await FileUtils.createFolder(
                  path.join(_currentDir, folderName),
                );
                if (success) {
                  _loadFiles(dirPath: _currentDir);
                  if (mounted) {
                    Utils.showToast(context, 'folder_create_success'.tr());
                  }
                } else {
                  if (mounted) {
                    Utils.showToast(context, 'folder_create_failed'.tr());
                  }
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('create'.tr()),
          ),
        ],
      ),
    );
  }

  // 原有方法：新建MD文件（保留）
  Future<void> _showCreateMdFileDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('new_note'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'new_note_hint'.tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final fileName = controller.text.trim();
              if (fileName.isNotEmpty) {
                final file = await FileUtils.createMdFile(
                  fileName,
                  parentPath: _currentDir,
                );
                Provider.of<CountProvider>(context, listen: false).refresh();
                Navigator.pop(context);
                if (file != null) {
                  _loadFiles(dirPath: _currentDir);
                } else {
                  if (mounted) {
                    Utils.showToast(
                        context, 'file_exist_or_create_failed'.tr());
                  }
                }
              }
            },
            child: Text('create_markdown'.tr()),
          ),
          SizedBox(
            width: 10,
          ),
          TextButton(
            onPressed: () async {
              final fileName = controller.text.trim();
              if (fileName.isNotEmpty) {
                final file = await FileUtils.createHtmlFile(
                  fileName,
                  parentPath: _currentDir,
                );
                Provider.of<CountProvider>(context, listen: false).refresh();
                Navigator.pop(context);
                if (file != null) {
                  _loadFiles(dirPath: _currentDir);
                } else {
                  if (mounted) {
                    Utils.showToast(
                        context, 'file_exist_or_create_failed'.tr());
                  }
                }
              }
            },
            child: Text('create_rich'.tr()),
          ),
        ],
      ),
    );
  }

  // 原有方法：批量删除（保留）
  Future<void> _showDeleteDialog(Set<dynamic> selectedItems) async {
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
                for (var entity in selectedItems) {
                  if (entity is Directory) {
                    await entity.delete(recursive: true);
                  } else {
                    await entity.delete();
                  }
                }

                _loadFiles(dirPath: _currentDir);
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
                  await DatabaseHelper()
                      .deleteRecord(entity.path.split("/").last);
                }
                _loadFiles(dirPath: _currentDir);
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

  // 原有方法：点击文件/文件夹（保留）
  void _onItemTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _loadFiles(dirPath: entity.path);
    } else if (entity is File && path.extension(entity.path) == '.md') {
      final fileName = path.basenameWithoutExtension(entity.path);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorPage(
            filePath: entity.path,
            fileName: fileName,
          ),
        ),
      );
    } else if (entity is File && path.extension(entity.path) == '.gtx') {
      final fileName = path.basenameWithoutExtension(entity.path);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditPage(
            filePath: entity.path,
            fileName: fileName,
          ),
        ),
      );
    }
  }

  // 原有方法：切换选中状态（保留）
  void _toggleItemSelection(FileSystemEntity entity) {
    setState(() {
      if (_selectedIds.contains(entity)) {
        _selectedIds.remove(entity);
      } else {
        _selectedIds.add(entity);
      }
    });
  }

  // 新增：构建列表视图项（带内容预览）
  Widget _buildListItem(FileSystemEntity entity) {
    final name = path.basename(entity.path).split(".").first;
    String e = path.extension(entity.path);
    final isDir = entity is Directory;
    final isSelected = _selectedIds.contains(entity);

    return FutureBuilder(
      future: Future.wait([
        _getModifiedTime(entity),
        if (!isDir) _getFilePreviewContent(entity.path)
      ]),
      initialData: ['loading'.tr(), ''],
      builder: (context, snapshot) {
        final modifyTime = snapshot.data?[0] ?? 'unknown_time'.tr();
        // _getFilePreviewContent(entity.path);snapshot.data?[i! - 1] ??
        final i = snapshot.data?.length;
        // final previewContent = isDir ? "" : "";
        //
        final previewContent = isDir
            ? 'folder'.tr()
            : e == '.md'
                ? (snapshot.data?[i! - 1] ?? '')
                : "富文本";
        // (snapshot.data?[0] ?? '') snapshot.data?[i!-1] ??

        return Card(
          elevation: 0,

          color: ThemeUtil.getIsDark() ? Colors.black : Colors.white,
          // margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          // shape: RoundedRectangleBorder(
          //   borderRadius: BorderRadius.circular(12),
          //   side: BorderSide(
          //     color: Colors.grey.shade300,
          //   ),
          // ),
          // decoration: BoxDecoration(
          //   color: ThemeUtil.getIsDark() ? Colors.black : Colors.white,
          //   borderRadius: BorderRadius.circular(12),
          //   // boxShadow: [

          //   //   RoundedRectangleBorder(
          //   //     borderRadius: BorderRadius.circular(12),
          //   //     side: BorderSide(
          //   //       color: Colors.grey,
          //   //     ),
          //   //   ),
          //   //   BoxShadow(
          //   //     color: ThemeUtil.getIsDark()
          //   //         ? const Color.fromARGB(115, 153, 153, 153)
          //   //         : Colors.grey.shade50,
          //   //     blurRadius: 3,
          //   //     // offset: const Offset(0, 1),
          //   //   ),
          //   // ],
          // ),
          child: Stack(
            children: [
              ListTile(
                // minVerticalPadding: EdgeInsets.all(10),
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
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (previewContent.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Text(
                          e == '.md'
                              ? Utils.removeMarkdownFormat(previewContent)
                              : Utils.removeHtmlTags(previewContent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    SizedBox(
                      height: 6,
                    ),
                    Text(
                        e == '.md'
                            ? "Markdown" +
                                " ・ " +
                                '${'modify_time'.tr()}${modifyTime}'
                            : e == '.gtx'
                                ? "富文本" +
                                    " ・ " +
                                    '${'modify_time'.tr()}${modifyTime}'
                                : 'folder'.tr() +
                                    " ・ " +
                                    '${'modify_time'.tr()}${modifyTime}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                onTap: () {
                  if (_isEditMode) {
                    _toggleItemSelection(entity);
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

  // 新增：构建网格视图项
  Widget _buildGridItem(FileSystemEntity entity) {
    final name = path.basename(entity.path).split(".").first;
    String e = path.extension(entity.path);
    final isDir = entity is Directory;
    final isSelected = _selectedIds.contains(entity);

    return FutureBuilder(
      future: Future.wait([
        _getModifiedTime(entity),
        if (!isDir) _getFilePreviewContent(entity.path)
      ]),
      initialData: ['loading'.tr(), ''],
      builder: (context, snapshot) {
        final modifyTime = snapshot.data?[0] ?? 'unknown_time'.tr();
        final i = snapshot.data?.length;
        // (snapshot.data?[0] ?? '') snapshot.data?[i! - 1] ??
        final previewContent = isDir ? 'folder'.tr() : "";

        return Stack(
          children: [
            Card(
              elevation: 0, // 去除阴影,使用边框代替
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              // margin: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12), // 与Card的圆角一致
                onTap: () {
                  if (_isEditMode) {
                    _toggleItemSelection(entity);
                  } else {
                    _onItemTap(entity);
                  }
                },
                onLongPress: () => _showOptionDialog(entity),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isDir ? Colors.blue[50] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                size: 48, // 图标放大
                                isDir
                                    ? Icons.folder
                                    : e == ".md"
                                        ? Icons.article_outlined
                                        : Icons.article_outlined,
                                color:
                                    isDir ? Colors.blue[700] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          modifyTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isEditMode)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  alignment: Alignment.center,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  // 原有方法：删除选中项（保留）
  void _deleteSelectedItems() {
    if (_selectedIds.isEmpty) {
      Utils.showToast(context, "select_image_to_delete".tr());
      return;
    }

    setState(() {
      _showDeleteDialog(_selectedIds);
    });
  }

  // 原有状态：FAB展开
  bool _isFabExpanded = false;

  // 原有方法：构建悬浮按钮（保留）
  Widget _buildFloatingActionButtons() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_isFabExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: _buildSubFab(
              icon: Icons.delete,
              label: "delete".tr(),
              color: Colors.red,
              onPressed: () {
                if (_isEditMode) {
                  _isFabExpanded = false;
                  _isEditMode = false;
                }
                _deleteSelectedItems();
              },
            ),
          ),
        if (_isFabExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 180),
            child: _buildSubFab(
              icon: Icons.create,
              label: "new_note".tr(),
              color: Colors.blue,
              onPressed: () {
                _showCreateMdFileDialog();
                _isFabExpanded = false;
                _isEditMode = false;
              },
            ),
          ),
        if (_isFabExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: _buildSubFab(
              icon: Icons.create_new_folder,
              label: "new_folder".tr(),
              color: Colors.green,
              onPressed: () {
                _showCreateFolderDialog();
                _isFabExpanded = false;
                _isEditMode = false;
              },
            ),
          ),
        FloatingActionButton(
          onPressed: () {
            setState(() {
              if (!_isEditMode) {
                _selectedIds.clear();
              }
              _isEditMode = !_isEditMode;
              _isFabExpanded = !_isFabExpanded;
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: _isFabExpanded ? Colors.orange : Colors.grey,
          child: Icon(_isFabExpanded ? Icons.close : Icons.add,
              color: Colors.white),
          isExtended: true,
          tooltip: _isFabExpanded ? "collapse".tr() : "more_operation".tr(),
        ),
      ],
    );
  }

  // 原有方法：子FAB构建（保留）
  Widget _buildSubFab({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: Icon(icon, color: Colors.black),
      backgroundColor: color,
      isExtended: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (!didPop) {
            if (_currentDir != _rootDir) {
              final parentDir = path.dirname(_currentDir);
              _loadFiles(dirPath: parentDir);
            } else {
              FlutterExitApp.exitApp();
            }
          }
        },
        child: Scaffold(
          // 新增：添加AppBar，包含搜索框和视图切换
          appBar: AppBar(
            title: _buildSearchBar(),
            actions: [
              Container(
                margin: EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    _currentViewType == ViewType.list
                        ? Icons.grid_view
                        : Icons.list,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentViewType = _currentViewType == ViewType.list
                          ? ViewType.grid
                          : ViewType.list;
                    });
                  },
                  tooltip: _currentViewType == ViewType.list
                      ? 'switch_to_grid'.tr()
                      : 'switch_to_list'.tr(),
                ),
              )

              // 视图切换按钮
            ],
          ),
          body: Container(
            height: double.infinity,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (_currentDir != _rootDir)
                    ListTile(
                      onTap: () {
                        final parentDir = path.dirname(_currentDir);
                        _loadFiles(dirPath: parentDir);
                      },
                      title: Text('back_to_parent_dir'.tr()),
                      leading:
                          const Icon(Icons.arrow_upward, color: Colors.blue),
                      onLongPress: () {},
                    ),

                  // 加载中状态
                  if (_isSearching)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: Center(
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )

                  // 空结果状态
                  else if (_filteredFileList.isEmpty)
                    Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchKeyword.isNotEmpty
                                ? Icons.search_off
                                : Icons.folder_copy,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchKeyword.isNotEmpty
                                ? 'no_search_results'.tr()
                                : 'no_files_or_dirs'.tr(),
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )

                  // 列表视图
                  else if (_currentViewType == ViewType.list)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredFileList.length,
                      itemBuilder: (context, index) =>
                          _buildListItem(_filteredFileList[index]),
                    )

                  // 网格视图
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2, // 2列网格
                      childAspectRatio: 0.8, // 宽高比
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: _filteredFileList
                          .map((entity) => _buildGridItem(entity))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildFloatingActionButtons(),
        ));
  }

  // 新增：构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 16),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _filterFiles(),
        decoration: InputDecoration(
          hintText: 'search_files'.tr(),
          hintStyle: TextStyle(
            fontSize: 1,
            color: Colors.grey[400],
          ),
          // 搜索图标
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 22,
          ),
          // 清除按钮(可选)
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _filterFiles();
                  },
                )
              : null,
          // 关键:设置内边距使内容垂直居中
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          // 去除边框
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          // 确保图标垂直居中
          isDense: true,
        ),
      ),
    );
  }
}
