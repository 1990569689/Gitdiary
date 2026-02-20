import 'package:editor/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 必须导入

enum DarkModeType {
  normal, // 亮色
  pureBlack, // 暗色
}

class Utils {
  /// 强力移除所有 Markdown 格式符号，最大化保留纯文本（宁可误除，不可保留）
  /// [markdownText]：带 Markdown 格式的原始文本
  /// 返回：无任何MD格式的纯文字内容
  static String removeMarkdownFormat(String markdownText) {
    if (markdownText.isEmpty) return "";

    String pureText = markdownText;

    // 1. 移除所有标题符号（#，无论位置/数量，彻底删除）
    pureText = pureText.replaceAll(RegExp(r'#'), '');

    // 2. 移除所有粗体/斜体符号（*、_，全部删除，无例外）
    pureText = pureText.replaceAll(RegExp(r'\*|_'), '');

    // 3. 移除所有代码相关符号（`，包括单行/多行代码块的`，彻底删除）
    pureText = pureText.replaceAll(RegExp(r'`'), '');

    // 4. 移除链接格式（[文字](链接) → 直接删除[]()及内部所有内容，宁可误除）
    // 匹配所有 [任意内容](任意内容) 结构，彻底删除
    pureText = pureText.replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '');

    // 5. 移除所有列表符号（-、+、*，无论位置，全部删除）
    pureText = pureText.replaceAll(RegExp(r'[-+*]'), '');

    // 6. 移除所有引用符号（>，无论位置，全部删除）
    pureText = pureText.replaceAll(RegExp(r'>'), '');

    // 7. 移除表格相关符号（|、-，Markdown表格的核心符号，彻底删除）
    pureText = pureText.replaceAll(RegExp(r'\||-'), '');

    // 8. 移除水平线符号（---、*** 等，匹配连续的-/*，彻底删除）
    pureText = pureText.replaceAll(RegExp(r'[-*]{3,}'), '');

    // 9. 清理格式残留的空白（多个换行/空格合并为一个，首尾去空）
    pureText = pureText
        .replaceAll(RegExp(r'\n+'), '\n') // 多个换行→一个
        .replaceAll(RegExp(r'\s+'), ' ') // 多个空格→一个
        .trim();

    return pureText;
  }

  /// 强力移除所有 HTML 标签及相关字符，最大化保留纯文本（宁可误除，不可保留）
  /// [htmlText]：带 HTML 标签的原始文本
  /// 返回：无任何HTML格式的纯文字内容
  static String removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return "";

    String pureText = htmlText;

    // 1. 核心：移除所有 HTML 标签（包括嵌套/自闭和/带属性的标签，彻底删除）
    // 匹配规则：< 开头 → 任意字符（包括换行）→ > 结尾，全覆盖无遗漏
    pureText = pureText.replaceAll(RegExp(r'<[\s\S]*?>'), '');
    pureText = pureText.replaceAll("/", '');
    pureText = pureText.replaceAll("<", '');
    // 2. 移除所有 HTML 转义字符（扩展全量转义符，彻底替换）
    pureText = pureText
        .replaceAll('&nbsp;', ' ') // 空格
        .replaceAll('&lt;', '<') // 小于号
        .replaceAll('&gt;', '>') // 大于号
        .replaceAll('&amp;', '&') // 和号
        .replaceAll('&quot;', '"') // 双引号
        .replaceAll('&apos;', "'") // 单引号
        .replaceAll('&cent;', '¢') // 分
        .replaceAll('&pound;', '£') // 镑
        .replaceAll('&yen;', '¥') // 元
        .replaceAll('&euro;', '€') // 欧元
        .replaceAll('&copy;', '©') // 版权
        .replaceAll('&reg;', '®'); // 注册商标

    // 3. 移除所有可能的标签残留字符（div、b、span等标签名，宁可误除）
    // 匹配常见HTML标签名，彻底删除（按需扩展）
    pureText = pureText.replaceAll(
        RegExp(
            r'div|b|span|p|a|img|ul|li|ol|h1|h2|h3|h4|h5|h6|br|hr|table|tr|td|th',
            caseSensitive: false),
        '');

    // 4. 清理空白（多个空格/换行合并，首尾去空）
    pureText = pureText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return pureText;
  }

  /// 组合方法：同时移除 Markdown + HTML 格式（推荐使用）
  static String removeAllFormat(String text) {
    if (text.isEmpty) return "";
    // 先移除HTML，再移除MD，避免格式冲突
    String result = removeHtmlTags(text);
    result = removeMarkdownFormat(result);
    return result;
  }

  // 读取：是否首次启动（默认true）
  static Future<bool> checkFirstLaunch() async {
    return _prefs.getBool("first_launch") ?? true;
  }

  // 写入：标记已完成引导，后续不再显示
  static Future<void> setIntroCompleted() async {
    await _prefs.setBool("first_launch", false);
  }

  static Future<void> clearPreferences() async {
    await _prefs.clear();
  }

  static Future<void> removePreference(String key) async {
    await _prefs.remove(key);
  }

  static Future<void> saveLanguage(String language) async {
    await _prefs.setString('language', language);
  }

  // 设置白底黑字
  static void setWhiteBlack() {
    if(ThemeUtil.getIsDark())
      {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ));
      }else{
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ));
    }

  }

  // ========== 语言设置相关 ==========
  // 获取保存的语言（默认中文）
  static String getLanguage() {
    return _prefs.getString('language') ?? 'zh';
  }

  // ========== 主题设置相关 ==========
  // 保存主题模式（0=跟随系统，1=亮色，2=暗色）
  static Future<void> saveThemeMode(int mode) async {
    await _prefs.setInt('theme_mode', mode);
  }

  // 获取主题模式（默认0=跟随系统）
  static int getThemeMode() {
    return _prefs.getInt('theme_mode') ?? 0;
  }

  /// 解析版本号为数字列表（如 "1.2.3" → [1,2,3]）
  static List<int> parseVersion(String version) {
    // 处理异常版本号（空、非标准格式）
    if (version.isEmpty || !version.contains('.')) {
      return [0, 0, 0];
    }
    return version.split('.').map((part) {
      try {
        return int.parse(part);
      } catch (e) {
        return 0;
      }
    }).toList();
  }

  /// 对比版本号：remoteVersion > localVersion 时返回 true（有更新）
  static bool isNewVersion(String localVersion, String remoteVersion) {
    final localParts = parseVersion(localVersion);
    final remoteParts = parseVersion(remoteVersion);

    // 补全版本号段（确保长度一致，如 1.1 → [1,1,0]）
    final maxLength = localParts.length > remoteParts.length
        ? localParts.length
        : remoteParts.length;

    for (int i = 0; i < maxLength; i++) {
      final local = i < localParts.length ? localParts[i] : 0;
      final remote = i < remoteParts.length ? remoteParts[i] : 0;

      if (remote > local) {
        return true; // 远程版本更高
      } else if (remote < local) {
        return false; // 远程版本更低
      }
      // 相等则继续比较下一段
    }
    return false; // 版本号完全相同
  }

  List<String> gitignoreTemplates = [
    'None',
    'Actionscript',
    'Ada',
    'Agda',
    'Android',
    'AppEngine',
    'AppceleratorTitanium',
    'ArchLinuxPackages',
    'Autotools',
    'C',
    'C++',
    'CFWheels',
    'CMake',
    'CUDA',
    'CakePHP',
    'ChefCookbook',
    'Clojure',
    'CodeIgniter',
    'CommonLisp',
    'Composer',
    'Concrete5',
    'Coq',
    'CraftCMS',
    'D',
    'DM',
    'Dart',
    'Delphi',
    'Drupal',
    'EPiServer',
    'Eagle',
    'Elisp',
    'Elixir',
    'Elm',
    'Erlang',
    'ExpressionEngine',
    'ExtJS',
    'Fancy',
    'Finale',
    'ForceDotCom',
    'Fortran',
    'FuelPHP',
    'GWT',
    'GitBook',
    'Go',
    'Godot',
    'Gradle',
    'Grails',
    'Haskell',
    'IGORPro',
    'Idris',
    'JENKINS_HOME',
    'Java',
    'Jboss',
    'Jekyll',
    'Joomla',
    'Julia',
    'KiCAD',
    'Kohana',
    'Kotlin',
    'LabVIEW',
    'Laravel',
    'Leiningen',
    'LemonStand',
    'Lilypond',
    'Lithium',
    'Lua',
    'Magento',
    'Maven',
    'Mercury',
    'MetaprogrammingSystem',
    'Nim',
    'Node',
    'OCaml',
    'Objective-C',
    'Opa',
    'OracleForms',
    'Packer',
    'Perl',
    'Perl6',
    'Phalcon',
    'PlayFramework',
    'Plone',
    'Prestashop',
    'Processing',
    'PureScript',
    'Python',
    'Qooxdoo',
    'Qt',
    'R',
    'ROS',
    'Rails',
    'RhodesRhomobile',
    'Ruby',
    'Rust',
    'SCons',
    'Sass',
    'Scala',
    'Scheme',
    'Scrivener',
    'Sdcc',
    'SeamGen',
    'SketchUp',
    'Smalltalk',
    'SugarCRM',
    'Swift',
    'Symfony',
    'SymphonyCMS',
    'TeX',
    'Terraform',
    'Textpattern',
    'TurboGears2',
    'Typo3',
    'Umbraco',
    'Unity',
    'UnrealEngine',
    'VVVV',
    'VisualStudio',
    'Waf',
    'WordPress',
    'Xojo',
    'Yeoman',
    'Yii',
    'ZendFramework',
    'Zephir',
    'gcov',
    'nanoc',
    'opencart',
    'stella',
  ];

  Map<String, String> licenseTemplate = {
    'None': 'None',
    'Apache License 2.0': 'apache-2.0',
    'GNU General Public License v3.0': 'gpl-3.0',
    'MIT License': 'mit',
    'BSD 2-Clause "Simplified" License': 'bsd-2-clause',
    'BSD 3-Clause "New" or "Revised" License': 'bsd-3-clause',
    'Boost Software License 1.0': 'bsl-1.0',
    'Creative Commons Zero v1.0 Universal': 'cc0-1.0',
    'Eclipse Public License 2.0': 'epl-2.0',
    'GNU Affero General Public License v3.0': 'agpl-3.0',
    'GNU General Public License v2.0': 'gpl-2.0',
    'GNU Lesser General Public License v2.1': 'lgpl-2.1',
    'Mozilla Public License 2.0': 'mpl-2.0',
    'The Unlicense': 'unlicense',
  };

  static late SharedPreferences _prefs;

  // 存储首次启动时间的key（自定义，保证唯一即可）
  static const String _firstLaunchTimeKey = 'app_first_launch_time';

  // 初始化首次启动时间（应用首次打开时调用）
  static Future<void> initFirstLaunchTime() async {
    // 检查是否已存储过首次启动时间，未存储则记录当前时间戳
    if (!_prefs.containsKey(_firstLaunchTimeKey)) {
      final nowTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setInt(_firstLaunchTimeKey, nowTimestamp);
    }
  }

  /// 获取软件使用天数
  /// 返回值：使用天数（首次打开返回0，按自然天计算）
  static Future<int> getUsageDays() async {
    // 读取首次启动时间戳
    final firstLaunchMs = _prefs.getInt(_firstLaunchTimeKey);
    // 异常情况：无记录重新初始化并返回0
    if (firstLaunchMs == null) {
      await initFirstLaunchTime();
      return 0;
    }
    // 转换为DateTime对象，并剔除时分秒（只保留年月日）
    final firstLaunchTime = DateTime.fromMillisecondsSinceEpoch(firstLaunchMs);
    final firstLaunchDate = DateTime(
      firstLaunchTime.year,
      firstLaunchTime.month,
      firstLaunchTime.day,
    );
    // 当前时间也剔除时分秒，保证按自然天计算
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);

    // 计算自然天差值
    final usageDays = nowDate.difference(firstLaunchDate).inDays;
    return usageDays;
  }

  // ========== 新增：深色模式细分配置 ==========
  // 保存深色模式类型
  static Future<void> saveDarkModeType(String type) async {
    await _prefs.setString('dark_mode_type', type);
  }

  // 获取深色模式类型（默认normal）
  static String getDarkModeType() {
    return _prefs.getString('dark_mode_type') ?? DarkModeType.normal.name;
  }

  // 初始化存储（APP启动时调用，建议在main.dart中初始化）
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await Utils.initFirstLaunchTime();
  }

  // 示例：存值/取值方法（避免直接暴露 _prefs）
  static Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs.getString(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs.getInt(key);
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  // ========== Github 配置相关 ==========
  // Github
  static Future<void> saveGithubConfig({
    required String owner,
    required String token,
  }) async {
    await _prefs.setString('github_owner', owner);

    await _prefs.setString('github_token', token);
  }

  // 获取Gitee配置（返回Map，无数据则返回默认值）
  static Map<String, String> getGithubConfig() {
    return {
      'owner': _prefs.getString('github_owner') ?? '',
      'token': _prefs.getString('github_token') ?? '',
    };
  }

  static Future<void> saveAiConfig({
    required String name,
    required String api,
    required String token,
    required String model,
  }) async {
    await _prefs.setString('chat_api', api);
    await _prefs.setString('chat_model', model);
    await _prefs.setString('chat_name', name);
    await _prefs.setString('chat_token', token);
  }

  // 获取Gitee配置（返回Map，无数据则返回默认值）
  static Map<String, String> getAiConfig() {
    return {
      'api': _prefs.getString('chat_api') ?? 'https://api.siliconflow.cn/v1',
      'model': _prefs.getString('chat_model') ?? '未设置',
      'name': _prefs.getString('chat_name') ?? '硅基流动',
      'token': _prefs.getString('chat_token') ?? '未设置',
    };
  }
  //  static Future<void> saveCreateRepoConfig({
  //   required String name,
  //   required String description,
  //   required bool private,
  //   required String auto_init,
  // }) async {
  //   await _prefs.setString('github_repo', name);
  //   await _prefs.setString('github_description', description);
  //   await _prefs.setString('github_private', private.toString());
  //   await _prefs.setString('github_auto_init', auto_init);
  // }

  // // 获取Gitee配置（返回Map，无数据则返回默认值）
  // static Map<String, String> getCreateRepoConfig() {
  //   return {
  //     'repo': _prefs.getString('github_repo') ?? '',
  //     'message': _prefs.getString('github_message') ?? '',
  //     'branch': _prefs.getString('github_branch') ?? '',
  //   };
  // }

  static Future<void> saveWriteConfig({
    required bool viewCount,
    required String linkColor,
    required String quoteColor,
    required String codeFontColor,
    required String codeBgColor,
    required double fontSize,
    required int imageQuality,
    required int autoTimes,
    required int render,
    required String quoteTextColor,
  }) async {
    await _prefs.setBool('write_view_count', viewCount);
    await _prefs.setString('write_link_color', linkColor);
    await _prefs.setString('write_quote_color', quoteColor);
    await _prefs.setString('write_code_font_color', codeFontColor);
    await _prefs.setString('write_quote_text_color', quoteTextColor);
    await _prefs.setString('write_code_bg_color', codeBgColor);
    await _prefs.setDouble('write_font_size', fontSize);
    await _prefs.setInt('write_image_quality', imageQuality);
    await _prefs.setInt('write_auto_times', autoTimes);
    await _prefs.setInt('write_mark_render', render);
  }

  // 获取配置（返回Map，无数据则返回默认值）
  static Map<String, dynamic> getWriteConfig() {
    return {
      'mark_render': _prefs.getInt('write_mark_render') ?? 2,
      'view_count': _prefs.getBool('write_view_count') ?? true,
      'link_color': _prefs.getString('write_link_color') ?? '',
      'quote_color': _prefs.getString('write_quote_color') ?? '',
      'quote_text_color': _prefs.getString('write_quote_text_color') ?? '',
      'code_font_color': _prefs.getString('write_code_font_color') ?? '',
      'code_bg_color': _prefs.getString('write_code_bg_color') ?? '',
      'font_size': _prefs.getDouble('write_font_size') ?? 20.0,
      'image_quality': _prefs.getInt('write_image_quality') ?? 80,
      'auto_times': _prefs.getInt('write_auto_times') ?? 5,
    };
  }

  static Future<void> saveBackupsConfig({
    required bool? isAutoBackups,
    required String local,
    required String user,
    required String pass,
    required String path,
  }) async {
    await _prefs.setBool('backups_is_auto', isAutoBackups ?? false);
    await _prefs.setString('backups_local', local);
    await _prefs.setString('backups_user', user);
    await _prefs.setString('backups_pass', pass);
    await _prefs.setString('backups_path', path);
  }

  // 获取Gitee配置（返回Map，无数据则返回默认值）
  static Map<String, dynamic> getBackupsConfig() {
    return {
      'is_auto': _prefs.getBool('backups_is_auto') ?? false,
      'local': _prefs.getString('backups_local') ??
          'https://dav.jianguoyun.com/dav/',
      'user': _prefs.getString('backups_user') ?? '未设置',
      'pass': _prefs.getString('backups_pass') ?? '未设置',
      'path': _prefs.getString('backups_path') ?? 'Gitdiary',
    };
  }

  static Future<void> saveGitConfig({
    required bool isDialog,
    required String repo,
    required String branch,
    required String message,
    required String imagePath,
  }) async {
    await _prefs.setString('github_image_path', imagePath);

    await _prefs.setBool('github_is_dialog', isDialog);
    await _prefs.setString('github_repo', repo);
    await _prefs.setString('github_message', message);
    await _prefs.setString('github_branch', branch);
  }

  // 获取Gitee配置（返回Map，无数据则返回默认值）
  static Map<String, dynamic> getGitConfig() {
    return {
      'image': _prefs.getString('github_image_path') ?? 'images',
      'dialog': _prefs.getBool('github_is_dialog') ?? false,
      'repo': _prefs.getString('github_repo') ?? 'Gitdiary',
      'message': _prefs.getString('github_message') ??
          'Update ${DateTime.now().toIso8601String()}',
      'branch': _prefs.getString('github_branch') ?? 'master',
    };
  }

  static Future<void> saveGithubUserConfig({
    required String name,
    required String sign,
    required String avatar,
    required String company,
    required String blog,
    required String location,
    required String email,
    required String following,
    required String followers,
    required String public_repos,
    required String public_gists,
  }) async {
    await _prefs.setString('github_name', name);
    await _prefs.setString('github_sign', sign);
    await _prefs.setString('github_avatar', avatar);
    await _prefs.setString('github_company', company);
    await _prefs.setString('github_blog', blog);
    await _prefs.setString('github_location', location);
    await _prefs.setString('github_email', email);
    await _prefs.setString('github_following', following);
    await _prefs.setString('github_followers', followers);
    await _prefs.setString('github_public_repos', public_repos);
    await _prefs.setString('github_public_gists', public_gists);
  }

  // 获取Gitee配置（返回Map，无数据则返回默认值）
  static Map<String, String> getGithubUserConfig() {
    return {
      'name': _prefs.getString('github_name') ?? '登录账号',
      'sign': _prefs.getString('github_sign') ?? '未登录',
      'avatar': _prefs.getString('github_avatar') ?? '',
      'company': _prefs.getString('github_company') ?? '',
      'blog': _prefs.getString('github_blog') ?? '',
      'location': _prefs.getString('github_location') ?? '',
      'email': _prefs.getString('github_email') ?? '',
      'following': _prefs.getString('github_following') ?? '',
      'followers': _prefs.getString('github_followers') ?? '',
      'public_repos': _prefs.getString('github_public_repos') ?? '',
      'public_gists': _prefs.getString('github_public_gists') ?? '',
    };
  }

  // 格式化日期时间
  static String formatDateTime() {
    DateTime now = DateTime.now();
    return DateFormat('MM月dd日 HH:mm').format(now); // 2026-01-04 15:30:20
  }

  // 提示框
  static void showToast(BuildContext context, String message) {
    try {
      showToastWidget(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
            ),
          ),
          position: ToastPosition.bottom,
          duration: const Duration(seconds: 4));
    } catch (e) {
      // 忽略取消异常
      return;
    }

    // 使用 OKToast 替代 SnackBar
    // showToast(message);
  }
}
