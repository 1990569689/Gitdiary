import 'package:easy_localization/easy_localization.dart';
import 'package:editor/page/calender/calender_page.dart';
import 'package:editor/page/home/home_page.dart';
import 'package:editor/page/model/model_page.dart';
import 'package:editor/page/person/github_api.dart';
import 'package:editor/page/person/person_page.dart';
import 'package:editor/provider.dart';
import 'package:editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Index extends StatefulWidget {
  const Index({super.key});

  @override
  State<Index> createState() => _IndexState();
}

class _IndexState extends State<Index> {
  int currentIndex = 0;
  // 控制NavigationRail是否展开
  bool _isRailExpanded = true;
  bool _isDownloading = false;
  int _downloaded = 0;
  int _total = 0;
  // 触发下载（替换为你的仓库信息）
  Future<void> _showDialog({
    required String title,
  }) async {
    _downloaded = 0;
    _total = 0;
    // 替换原来的三个控制器，只保留一个用于输入 GitHub 地址
    final TextEditingController urlController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'github_url_hint'
                    .tr(), // 建议修改提示文本为 "GitHub 仓库地址，如 https://github.com/owner/repo"
                // labelText: 'GitHub 仓库地址',
              ),
              autofocus: true,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            Text(
              "github_download_tips".tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              // 1. 清空输入框直接返回
              if (urlController.text.trim().isEmpty) return;
              // 2. 解析 GitHub 地址
              final parsedResult = _parseGitHubUrl(urlController.text.trim());
              if (parsedResult == null) {
                Utils.showToast(
                    context, 'github_url_invalid'.tr()); // 提示"无效的 GitHub 地址"
                return;
              }
              // 3. 提取解析后的参数
              final String owner = parsedResult['owner']!;
              final String repo = parsedResult['repo']!;
              final String branch = parsedResult['branch'] ?? 'master'; // 默认分支为 main
              // 4. 开始下载流程
              Utils.showToast(context, 'download_start'.tr());
              Navigator.pop(context);
              try {
                await _startDownload(owner, repo, branch);
              } catch (e) {
                // 捕获下载异常并提示，避免静默失败
                Utils.showToast(context, 'download_failed'.tr() + ': $e');
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
  /// 解析 GitHub 仓库地址，提取 owner、repo、branch
  /// 支持的格式示例：
  /// 1. https://github.com/owner/repo/tree/branch
  /// 2. https://github.com/owner/repo (默认分支)
  /// 3. owner/repo
  /// 4. owner/repo/tree/branch
  Map<String, String?>? _parseGitHubUrl(String url) {
    // 移除首尾空格和可能的斜杠
    url = url.trim().replaceAll(RegExp(r'\/$'), '');
    // 正则表达式匹配 GitHub 地址的核心逻辑
    final regex = RegExp(
      r'(?:https?:\/\/github\.com\/)?([^\/]+)\/([^\/]+)(?:\/tree\/([^\/]+))?',
      caseSensitive: false,
    );
    final match = regex.firstMatch(url);
    if (match == null) return null;
    return {
      'owner': match.group(1),
      'repo': match.group(2),
      'branch': match.group(3), // 可能为 null（未指定分支）
    };
  }
  // 新建MD文件弹窗
  // Future<void> _showDialog({
  //   required String title,
  // }) async {
  //   _downloaded = 0;
  //   _total = 0;
  //   final TextEditingController owner = TextEditingController();
  //   final TextEditingController repo = TextEditingController();
  //   final TextEditingController branch = TextEditingController();
  //   await showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(title),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           TextField(
  //             controller: owner,
  //             decoration:
  //                 InputDecoration(hintText: 'github_username_hint'.tr()),
  //             autofocus: true,
  //           ),
  //           TextField(
  //             controller: repo,
  //             decoration: InputDecoration(hintText: 'github_repo_hint'.tr()),
  //             autofocus: true,
  //           ),
  //           TextField(
  //             controller: branch,
  //             decoration: InputDecoration(hintText: 'github_branch_hint'.tr()),
  //             autofocus: true,
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text('cancel'.tr()),
  //         ),
  //         TextButton(
  //           onPressed: () async {
  //             if (owner.text.isEmpty ||
  //                 repo.text.isEmpty ||
  //                 branch.text.isEmpty) return;
  //             Utils.showToast(context, 'download_start'.tr());
  //             Navigator.pop(context);
  //             try {
  //               await _startDownload(owner.text.toString(),
  //                   repo.text.toString(), branch.text.toString());
  //             } catch (e) {}
  //           },
  //           child: Text('confirm'.tr()),
  //         ),
  //         // Text(_downloaded.toString() + "/" + _total.toString())
  //       ],
  //     ),
  //   );
  // }

  Future<void> _startDownload(String owner, String repo, String branch) async {
    setState(() {
      _isDownloading = true;
      _downloaded = 0;
      _total = 0;
    });

    // 公有仓库示例（无需Token）
    final success = await GitHubFileDownloader.downloadRepoFiles(
      owner: owner, // 仓库所有者
      repo: repo, // 仓库名称
      branch: branch, // 分支
      token: null, // 私有仓库填GitHub Token，公有仓库传null
      onProgress: (downloaded, total) {
        setState(() {
          _downloaded = downloaded;
          _total = total;
          Provider.of<GitProvider>(context, listen: false).refresh();
        });
      },
    );

    setState(() => _isDownloading = false);

    // 提示结果
    if (mounted) {
      Provider.of<CountProvider>(context, listen: false).refresh();
      Utils.showToast(
          context, success ? 'download_success'.tr() : 'download_failed'.tr());
    }
  }

  final GlobalKey<HomeState> _homePageKey = GlobalKey<HomeState>();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth > 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(currentIndex == 0
            ? 'app_name'.tr()
            : currentIndex == 1
                ? "bottom_calendar".tr()
                : currentIndex == 2
                    ? 'bottom_model'.tr()
                    : 'person'.tr()),
        actions: [
          if (currentIndex == 0)
            IconButton(
              onPressed: () {
                _showDialog(title: 'get_github_files'.tr());
              },
              icon: Icon(Icons.add),
            )
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (useNavigationRail)
              NavigationRail(
                // 展开/收起状态
                extended: _isRailExpanded,
                // 背景色
                backgroundColor: Colors.white,
                // 当前选中索引
                selectedIndex: currentIndex,
                // 选中项颜色
                selectedIconTheme: const IconThemeData(color: Colors.blue),
                selectedLabelTextStyle: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                // 未选中项颜色
                unselectedIconTheme: const IconThemeData(color: Colors.grey),
                unselectedLabelTextStyle: const TextStyle(
                  color: Colors.grey,
                ),
                // 点击事件
                onDestinationSelected: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                // 导航项
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('bottom_home'.tr()),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('bottom_calendar'.tr()),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.move_to_inbox_rounded),
                    label: Text('bottom_model'.tr()),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_circle),
                    label: Text('bottom_person'.tr()),
                  ),
                ],
                // 展开/收起按钮
              ),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: [
                  Home(key: _homePageKey, title: "Gitdiary"),
                  CalenderPage(),
                  Model(),
                  Person(title: "Gitdiary"),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !useNavigationRail
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                setState(() {
                  Provider.of<UpdateProvider>(context, listen: false).refresh();
                  currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home,
                    size: 20,
                  ),
                  label: 'bottom_home'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                  ),
                  label: 'bottom_calendar'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.move_to_inbox_rounded,
                    size: 20,
                  ),
                  label: 'bottom_model'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.account_circle,
                    size: 20,
                  ),
                  label: 'bottom_person'.tr(),
                ),
              ],
            )
          : null,
    );
  }
}
