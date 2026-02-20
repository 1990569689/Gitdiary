import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/database.dart';
import 'package:editor/main.dart';
import 'package:editor/page/about/about_page.dart';
import 'package:editor/page/ai/chat_page.dart';
import 'package:editor/page/backups/backups_page.dart';
import 'package:editor/page/git/git_page.dart';

import 'package:editor/page/me/me_page.dart';
import 'package:editor/page/note/note_page.dart';
import 'package:editor/page/person/github_api.dart';
import 'package:editor/provider.dart';
import 'package:editor/theme.dart';
import 'package:editor/update.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/widget/dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 新增

class Person extends StatefulWidget {
  String title;
  Person({super.key, required this.title});

  @override
  State<Person> createState() => PersonState();
}

class PersonState extends State<Person> {
  String name = "login_account".tr();
  String avatarUrl = "";
  String sign = "not_login".tr();

  // 新增GitHub配置控制器
  late TextEditingController _githubOwnerController = TextEditingController();

  late TextEditingController _githubTokenController = TextEditingController();

  // 模拟热力图数据（key=日期，value=当日使用次数/频率）
  Map<DateTime, int> _heatMapData = {};
  int themeMode = Utils.getThemeMode();
  String themeModeStr = "";
  late CountProvider _git;
  bool _isLoading = false;
  int fileCount = 0;
  int charCount = 0;
  int _days = 0;
  List<String> errorFiles = [];

  // 缓存大小（格式化显示）
  String _cacheSize = "0 KB";
// 替换为你的QQ群号
  static const String _qqGroupNumber = "859976283";
  String? _localVersion; // 本地版本号
  // 构建QQ加群URL
  final Uri _qqGroupUri = Uri.parse(
      "mqqapi://card/show_pslcard?src_type=internal&version=1&uin=$_qqGroupNumber&card_type=group&source=qrcode");

  Future<void> _joinQQGroup() async {
    try {
      // 检查是否可以唤起URL
      if (await canLaunchUrl(_qqGroupUri)) {
        await launchUrl(
          _qqGroupUri,
          mode: LaunchMode.externalApplication, // 强制唤起外部QQ应用
        );
      } else {
        // 无法唤起URL（未安装QQ）
        Utils.showToast(context, "未检测到QQ客户端，请先安装QQ后重试");
      }
    } catch (e) {
      // 其他异常（如Scheme不支持、权限问题）
      // debugPrint("加入QQ群失败：$e");
      Utils.showToast(context, "加入群聊失败，请稍后重试");
    }
  }

  // 切换语言的方法
  void _changeLocale(Locale newLocale) async {
    // 保存语言设置到本地
    // 切换语言并刷新界面

    Utils.saveLanguage(newLocale.languageCode);
    try {
      await context.setLocale(newLocale);
      setState(() {
        themeMode = Utils.getThemeMode();
        switch (themeMode) {
          case 0:
            themeModeStr = "system_mode".tr();
            break;
          case 1:
            themeModeStr = "light_mode".tr();
            break;
          case 2:
            themeModeStr = "dark_mode".tr();
            break;
        }
      });
    } catch (e) {}
    // 触发UI重建
  }

  // 核心方法：递归遍历目录并统计
  Future<void> _statDirectory(FileSystemEntity dir) async {
    // 校验目录是否存在且为目录类型
    if (!await dir.exists() || dir is! Directory) {
      return;
    }

    try {
      // 遍历目录下的所有文件/文件夹（非递归）
      await for (var entity in dir.list(recursive: false)) {
        if (entity is File) {
          // 是文件：统计数量 + 读取字数
          fileCount++; // 仅累加1次，而非递归后翻倍
          try {
            // 仅处理文本文件（优化扩展名判断逻辑，修复无扩展名问题）
            final textExts = ['.txt', '.md'];
            final path = entity.path;
            final extIndex = path.lastIndexOf('.');
            String ext = '';
            // 确保扩展名存在且不是文件名开头（如".gitignore"不会误判）
            if (extIndex != -1 && extIndex < path.length - 1) {
              ext = path.substring(extIndex).toLowerCase();
            }

            if (textExts.contains(ext)) {
              // 读取文件内容并统计字符数（按UTF-8编码）
              String content = await entity.readAsString();
              charCount += content.length; // 正常累加字符数
            }
          } catch (e) {
            errorFiles.add('读取失败: ${entity.path}，原因: $e');
          }
        } else if (entity is Directory) {
          // 是文件夹：递归统计（核心修复点：移除错误的自增逻辑）
          await _statDirectory(entity);
          // 原错误代码：fileCount += fileCount; charCount += charCount; errorFiles.addAll(errorFiles);
          // 已删除——递归调用本身会自动累加子目录的统计结果，无需重复操作
        }
      }
    } catch (e) {
      errorFiles.add('遍历目录失败: ${dir.path}，原因: $e');
    }
  }

  void _showLanguageDialog(BuildContext context) {
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
                '中文简体',
                1,
              ),
              _buildLanguageOption(
                context,
                'English',
                2,
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
        mode == 1 ? '简体中文' : 'English',
      ),
      onTap: () {
        // 切换语言
        if (mode == 1) {
          _changeLocale(const Locale('zh', ''));
        } else if (mode == 2) {
          _changeLocale(const Locale('en', ''));
        }
        Navigator.pop(context); // 关闭弹窗
      },
      subtitle: Text(
        mode == 1 ? '简体中文' : 'English',
      ),
      trailing: (context.locale == const Locale('zh', '') && mode == 1) ||
              (context.locale == const Locale('en') && mode == 2)
          ? Icon(
              Icons.check,
              color: Colors.blue,
            )
          : null,
    );
  }

  // 显示主题选择弹窗
  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: const Text('选择主题模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                'light_mode'.tr(),
                1,
              ),
              _buildThemeOption(
                context,
                'dark_mode'.tr(),
                2,
              ),
              _buildThemeOption(
                context,
                'system_mode'.tr(),
                0,
              ),
            ],
          ),
          // actions: [
          //   TextButton(
          //     onPressed: () => Navigator.pop(context),
          //     child: const Text('取消'),
          //   ),
          // ],
        );
      },
    );
  }

  // 构建单个主题选项
  Widget _buildThemeOption(BuildContext context, String title, int mode) {
    return ListTile(
      subtitle: Text(
        mode == 1
            ? 'use_light_mode'.tr()
            : mode == 2
                ? 'use_dark_mode'.tr()
                : 'use_system_mode'.tr(),
      ),
      trailing: themeMode == mode
          ? Icon(
              Icons.check,
              color: Colors.blue,
            )
          : null,
      leading: Icon(
        mode == 1
            ? Icons.wb_sunny
            : mode == 2
                ? Icons.nights_stay
                : Icons.phone_iphone,
      ),
      title: Text(title),
      onTap: () {
        // 更新主题模式
        // 关闭弹窗
        Utils.saveThemeMode(mode); //
        // 保存主题模式设置
        // 2=深色，1=浅色
        MyApp.refreshTheme(context);
        setState(() {
          themeMode = Utils.getThemeMode();
          switch (themeMode) {
            case 0:
              themeModeStr = "system_mode".tr();
              break;
            case 1:
              themeModeStr = "light_mode".tr();
              break;
            case 2:
              themeModeStr = "dark_mode".tr();
              break;
          }
        });

        Navigator.pop(context);
        // 显示提示
        Utils.showToast(context, '${'theme_mode_changed'.tr()}$title');
      },
    );
  }

  /// 获取本地应用版本号
  /// 获取本地应用版本号（修正后）
  Future<void> _getLocalVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform(); // 核心修正：fromApp()
      setState(() {
        _localVersion = packageInfo.version; // 获取版本号（如 1.0.0）
        // 可选：还能获取 buildNumber（构建号）
        // _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _localVersion = '${'unknown_version'.tr()}'; // 异常兜底
      });
      debugPrint('获取本地版本号失败：$e');
    }
  }

  /// 计算图片缓存大小
  Future<void> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSize = await _getDirectorySize(cacheDir);
      setState(() {
        _cacheSize = _formatSize(cacheSize);
      });
    } catch (e) {
      setState(() {
        _cacheSize = "calculate_failed".tr();
      });
    }
  }

  /// 计算目录大小
  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    if (await dir.exists()) {
      await for (final FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    }
    return size;
  }

  /// 格式化文件大小（B → KB → MB）
  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  /// 清空图片缓存
  Future<void> _clearCache() async {
    try {
      // 清空CachedNetworkImage的缓存
      // await CachedNetworkImage.evictAllImagesFromMemory();
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      // 重新计算缓存大小
      await _calculateCacheSize();
      if (mounted) {
        Utils.showToast(context, "cache_cleared_success".tr());
      }
    } catch (e) {
      if (mounted) {
        Utils.showToast(context, "cache_cleared_failed".tr());
      }
    }
  }

  /// 检查更新
  Future<void> _checkUpdate(bool isManual) async {
    if (isManual) {
      Utils.showToast(context, 'check_update_hint'.tr());
    }
    await _getLocalVersion(); // 等待版本号获取完成
    final String giteeRawUrl =
        'https://gitee.com/Ddonging/Gitediary/raw/master/update.json';
    try {
      // 发起网络请求
      final dio = Dio();
      final response = await dio.get(giteeRawUrl);

      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析JSON

        final Map<String, dynamic> item = response.data;
        if (item.isNotEmpty) {
          final String version = item['version'] ?? "";
          final String title = item['title'] ?? "";
          final String content = item['content'] ?? "";
          final String url = item['url'] ?? "";
          UpdateInfoModel updateInfo = UpdateInfoModel(
            version: version,
            title: title,
            content: content,
            url: url,
          );
          if (Utils.isNewVersion(_localVersion!, version)) {
            _showUpdateDialog(updateInfo); // 有更新，显示弹窗
          } else {
            if (isManual) {
              Utils.showToast(
                  context, 'current_version_hint'.tr() + _localVersion!); // 无更新
            }
          }
          // 显示更新弹窗
          // _showUpdateDialog(updateInfo);
        } else {
          Utils.showToast(context, 'request_failed'.tr());
        }
      }
    } catch (e) {
      // 捕获异常（网络错误、解析错误等）
      Utils.showToast(context, 'check_update_failed'.tr());
    } finally {}
  }

  /// 显示更新弹窗
  void _showUpdateDialog(UpdateInfoModel updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false, // 点击外部不关闭
      builder: (context) => AlertDialog(
        title: Text('new_version_found'
            .tr()
            .replaceFirst('{version}', updateInfo.version)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(updateInfo.title),
            const SizedBox(height: 10),
            Text('update_content'.tr()),
            Text(updateInfo.content),
          ],
        ),
        actions: [
          // 取消按钮
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('update_later'.tr()),
          ),
          // 更新按钮
          TextButton(
            onPressed: () async {
              // 关闭弹窗并打开浏览器
              Navigator.pop(context);
              await _launchUrl(updateInfo.url);
            },
            child: Text('update_now'.tr()),
          ),
        ],
      ),
    );
  }

  /// 打开浏览器跳转链接
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Utils.showToast(context, 'open_link_failed'.tr() + url);
    }
  }

  /// 加载数据并转换为heatMapData格式
  Future<void> _loadHeatMapData() async {
    final records = await DatabaseHelper().getAllRecords();

    final Map<String, int> dayCountMap = {}; // 临时存储：日期字符串 -> 数量
    // 遍历记录，按“年月日”统计当日创建数量
    for (final record in records) {
      // 把时间戳转回DateTime
      final timestamp = record[DatabaseHelper.columnCreateTime] as int;
      final createTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      // 格式化日期为“yyyy-MM-dd”（只保留年月日）
      final dateStr = DateFormat('yyyy-MM-dd').format(createTime);
      // 统计当日数量
      dayCountMap[dateStr] = (dayCountMap[dateStr] ?? 0) + 1;
    }
    // 转换为目标格式：DateTime(年月日) -> 数量
    final Map<DateTime, int> heatMapData = {};
    dayCountMap.forEach((dateStr, count) {
      final dateParts = dateStr.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      heatMapData[DateTime(year, month, day)] = count;
    });
    // 更新状态
    setState(() {
      _heatMapData = heatMapData;

      // 使用天数 = 有记录的日期数量
    });
  }

  Future<void> _getUsageDays() async {
    _days = await Utils.getUsageDays();
  }

  // 触发统计（示例：统计应用文档目录）
  Future<void> _startStatistics() async {
    fileCount = 0;
    charCount = 0;
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取应用文档目录（可替换为其他目录，如临时目录）
      final appDir = await FileUtils.getAppDocDir();
      // 执行统计
      final folderPath = path.join(appDir.path, "diary");

      setState(() async {
        await _statDirectory(Directory(folderPath));
      });
    } catch (e) {
      setState(() {});
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 打开配置弹窗
  void _openLoginDialog() {
    Widget dialogContent = _buildGithubConfigForm();
    showDialog(
      context: context,
      builder: (_context) => AlertDialog(
        content: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // 适配小屏幕滚动
          child: dialogContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_context),
            child: Text("cancel".tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(_context);
              final owner = _githubOwnerController.text.trim();
              final token = _githubTokenController.text.trim();
              if (owner.isEmpty || token.isEmpty) {
                Utils.showToast(context, 'username_token_empty'.tr());
              } else {
                DialogWidget.show(context: context);
                Utils.saveGithubConfig(
                  owner: owner,
                  token: token,
                );

                try {
                  Map<String, dynamic> value = await GithubApi().getUserInfo();

                  Utils.showToast(context, "login_success".tr());

                  Utils.saveGithubUserConfig(
                    name: value['name'],
                    sign: value['bio'],
                    avatar: value['avatar_url'],
                    company: value['company'],
                    blog: value['blog'],
                    location: value['location'],
                    email: value['email'] ?? "未填写",
                    following: value['following'].toString(),
                    followers: value['followers'].toString(),
                    public_repos: value['public_repos'].toString(),
                    public_gists: value['public_gists'].toString(),
                  );
                  setState(() {
                    DialogWidget.dismiss(context);
                    name = value['name'];
                    sign = value['bio'];
                    avatarUrl = value['avatar_url'];
                  });
                } catch (e) {
                  // throw Exception("获取用户信息失败！$e");
                  // DialogWidget.dismiss(context);
                  Utils.showToast(context, "get_user_info_failed".tr());
                }
              }
            },
            child: Text("login".tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildGithubConfigForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey,
          backgroundImage: AssetImage('assets/images/github.png'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _githubOwnerController,
          decoration: InputDecoration(
            labelText: "github_username".tr(),
            hintText: "github_username_hint".tr(),
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person, size: 18),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _githubTokenController,
          decoration: InputDecoration(
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 1.0),
            ),
            labelText: "github_token".tr(),
            hintText: "github_token_need_repo".tr(),
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
    );
  }

  @override
  void dispose() {
    DatabaseHelper().close(); // 页面销毁时关闭数据库
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startStatistics();

    _git = Provider.of<CountProvider>(context, listen: false);
    _git.addListener(_startStatistics);

    _loadHeatMapData();
    _getUsageDays();
    _calculateCacheSize();
    _checkUpdate(false);
    switch (themeMode) {
      case 0:
        themeModeStr = "system_mode".tr();
        break;
      case 1:
        themeModeStr = "light_mode".tr();
        break;
      case 2:
        themeModeStr = "dark_mode".tr();
        break;
    }
// 初始化GitHub配置
    final githubConfig = Utils.getGithubConfig();
    final githubUserConfig = Utils.getGithubUserConfig();
    name = githubUserConfig['name']!;
    sign = githubUserConfig['sign']!;
    avatarUrl = githubUserConfig['avatar']!;
    // company = githubUserConfig['company'];
    // blog = githubUserConfig['blog'];
    // location = githubUserConfig['location'];
    // email = githubUserConfig['email'];
    // following = githubUserConfig['following'];
    // followers = githubUserConfig['followers'];
    // public_repos = githubUserConfig['public_repos'];
    // public_gists = githubUserConfig['public_gists'];
    _githubOwnerController = TextEditingController(text: githubConfig['owner']);

    _githubTokenController = TextEditingController(text: githubConfig['token']);
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前语言名称
    String langName = '';
    if (context.locale == const Locale('en')) {
      langName = 'English';
    } else if (context.locale == const Locale('zh', '')) {
      langName = '简体中文';
    } else if (context.locale == const Locale('zh', 'TW')) {
      langName = '繁体中文';
    }
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('个人中心'),
      //   actions: [
      //     IconButton(
      //         icon: Icon(Icons.refresh),
      //         onPressed: () {
      //           _loadHeatMapData();
      //             Utils.showToast(context, '${ThemeUtil.getIsDark()}');
      //           // fileCount = 0;
      //           // charCount = 0;
      //           // _startStatistics();
      //         })
      //   ],
      // ),
      body: Container(
        height: double.infinity,
        // 核心修改：移除外层无意义的ListView，改用SingleChildScrollView处理整体滚动
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            // 适配iOS/Android：iOS默认回弹，Android需自定义
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: ListTile(
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                  subtitle: Text(
                    maxLines: 3,
                    sign,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  title: Text(name),
                  leading: avatarUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 40,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover, // 确保图片覆盖整个容器
                              alignment: Alignment.center, // 确保图片居中
                              // 加载中占位
                              placeholder: (context, url) => const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              // 加载失败占位
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                          ),
                        )
                      : Image.asset('assets/images/github.png',
                          color: Colors.grey, width: 60, height: 60),
                  onTap: () async {
                    if (Utils.getGithubConfig()['owner'] == "" ||
                        Utils.getGithubConfig()['token'] == "") {
                      _openLoginDialog();
                    } else {
                      bool? result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MePage(),
                        ),
                      );
                      if (result == true) {
                        setState(() {
                          name = "login_account".tr();
                          sign = "not_login".tr();
                          avatarUrl = "";
                        });
                      }
                    }

                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => const LoginPage(),
                    //   ),
                    // );
                  },
                ),
              ),
              Card(
                margin: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                elevation: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('document_number'.tr(),
                                  style: TextStyle(fontSize: 16)),
                              Text(fileCount.toString() ?? '0',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('use_day_number'.tr(),
                                  style: TextStyle(fontSize: 16)),
                              Text(_days.toString() ?? '0',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('total_word_number'.tr(),
                                  style: TextStyle(fontSize: 16)),
                              Text(charCount.toString() ?? '0',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )),
                        ],
                      ),

                      // 2. 热力图区域
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // 热力图标题
                      Text(
                        'use_heat_map'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      HeatMapCalendar(
                          datasets: _heatMapData,
                          monthFontSize: 14,
                          flexible: true,
                          initDate: DateTime.now(),
                          showColorTip: true,
                          size: MediaQuery.of(context).size.width / 10,
                          colorsets: const {
                            1: Color.fromARGB(20, 20, 184, 166),
                            2: Color.fromARGB(40, 20, 184, 166),
                            3: Color.fromARGB(60, 20, 184, 166),
                            4: Color.fromARGB(80, 20, 184, 166),
                            5: Color.fromARGB(100, 20, 184, 166),
                            6: Color.fromARGB(120, 20, 184, 166),
                            7: Color.fromARGB(140, 20, 184, 166),
                            8: Color.fromARGB(160, 20, 184, 166),
                            9: Color.fromARGB(180, 20, 184, 166),
                            10: Color.fromARGB(200, 20, 184, 166),
                          })
                      // 核心热力图组件
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      trailing: IconButton(
                        icon: Text(_cacheSize),
                        onPressed: () {},
                      ),
                      title: Text('clear_cache'.tr()),
                      leading: Icon(
                        Icons.cleaning_services_outlined,
                        size: 20,
                      ),
                      onTap: () {
                        _clearCache();
                      },
                    ),
                    ListTile(
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('backups_and_sync'.tr()),
                      leading: Icon(
                        Icons.sync,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BackupsPage(),
                          ),
                        );
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
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('git_settings'.tr()),
                      leading: Icon(
                        Icons.publish_outlined,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GitPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('large_model_settings'.tr()),
                      leading: Icon(
                        Icons.electric_bolt_sharp,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('write_settings'.tr()),
                      leading: Icon(
                        Icons.article,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotePage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      trailing: IconButton(
                        icon: Text(themeModeStr),
                        onPressed: () {
                          _showThemeDialog(context);
                        },
                      ),
                      title: Text('theme_mode'.tr()),
                      leading: Icon(
                        Icons.color_lens_outlined,
                        size: 20,
                      ),
                      onTap: () {
                        setState(() {
                          _showThemeDialog(context);
                        });
                      },
                    ),
                    ListTile(
                      trailing: IconButton(
                        icon: Text(langName),
                        onPressed: () {},
                      ),
                      title: Text('change_language'.tr()),
                      leading: Icon(
                        Icons.language_outlined,
                        size: 20,
                      ),
                      onTap: () {
                        _showLanguageDialog(context);
                        // setState(() {
                        //   _showThemeDialog(context);
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
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('about'.tr()),
                      leading: Icon(
                        Icons.info_outlined,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AboutPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('check_update'.tr()),
                      leading: Icon(
                        Icons.update_outlined,
                        size: 20,
                      ),
                      onTap: () async {
                        await _checkUpdate(true);
                      },
                    ),
                    ListTile(
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      title: Text('join_qq_group'.tr()),
                      leading: Icon(
                        Icons.chat,
                        size: 20,
                      ),
                      onTap: () {
                        _joinQQGroup();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
