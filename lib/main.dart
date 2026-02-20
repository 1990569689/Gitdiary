import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:editor/database.dart';
import 'package:editor/index.dart';
import 'package:editor/introduction.dart';
import 'package:editor/page/home/home_page.dart';
import 'package:editor/provider.dart';
import 'package:editor/theme.dart';
import 'package:editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:markdown/markdown.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  // 标记：是否完成初始化（系统亮度已获取）
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 只保留一个主题模式变量，消除冗余
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // 当前生效的实际亮度（最终显示的模式）
  Brightness _currentBrightness = Brightness.light;
  Brightness get currentBrightness => _currentBrightness;

  // 快捷判断：是否为深色模式（核心依赖 _currentBrightness）
  bool get isDarkMode => _currentBrightness == Brightness.dark;

  ThemeProvider() {
    // 注册系统配置监听（亮度变化）
    WidgetsBinding.instance.addObserver(this);
    // 初始化：先获取系统亮度，再更新当前亮度
    _initSystemBrightness().then((_) {
      _isInitialized = true; // 初始化完成
      _updateCurrentBrightness();
    });
  }

  void refresh() {
    notifyListeners();
  }

  // 初始化系统亮度（异步获取）
  Future<void> _initSystemBrightness() async {
    try {
      String? brightnessStr = await SystemChannels.platform.invokeMethod(
        'SystemChrome.getPreferredBrightness',
      );
      _currentBrightness =
          brightnessStr == 'dark' ? Brightness.dark : Brightness.light;
    } catch (e) {
      debugPrint("获取系统亮度失败：$e");
      _currentBrightness = Brightness.light;
    }
  }

  // 核心：根据当前 ThemeMode 计算并更新实际亮度
  void _updateCurrentBrightness() {
    switch (_themeMode) {
      case ThemeMode.light:
        // 强制浅色
        _currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        // 强制深色
        _currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        // 跟随系统：无需修改 _currentBrightness（已通过 _initSystemBrightness 获取）
        break;
    }
    notifyListeners(); // 更新后通知UI刷新
  }

  // 设置主题模式（对外暴露的核心方法）
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return; // 避免重复设置
    _themeMode = mode;
    _updateCurrentBrightness(); // 恢复关键逻辑，确保亮度同步更新
  }

  // 监听系统亮度变化（核心修复：系统切换模式时更新亮度）
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // 只有跟随系统时，才更新亮度并通知
    if (_themeMode == ThemeMode.system) {
      _initSystemBrightness().then((_) {
        notifyListeners(); // 系统亮度变化后，通知UI刷新
      });
    }
    // refresh();
  }

  // 释放资源
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
// 主题状态管理类（核心）
// class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
//   ThemeMode _themeMode = ThemeMode.system;

//   ThemeProvider() {
//     // 注册监听，监听系统配置变化（包括亮度）
//     WidgetsBinding.instance.addObserver(this);
//     // 初始化时获取当前系统亮度，并监听变化
//     _initSystemBrightness();
//     _listenSystemBrightnessChange();
//   }

//   // 当前生效的亮度（最终显示的模式）
//   Brightness _currentBrightness = Brightness.light;
//   Brightness get currentBrightness => _currentBrightness;

//   // 应用的 ThemeMode 配置（可自定义：light/dark/system）
//   ThemeMode _appThemeMode = ThemeMode.system;
//   ThemeMode get appThemeMode => _appThemeMode;

//   // 初始化系统亮度
//   Future<void> _initSystemBrightness() async {
//     try {
//       // 获取系统首选亮度
//       String? brightness = await SystemChannels.platform.invokeMethod(
//         'SystemChrome.getPreferredBrightness',
//       );
//       _currentBrightness =
//           brightness == 'dark' ? Brightness.dark : Brightness.light;
//       notifyListeners();
//     } catch (e) {
//       _currentBrightness = Brightness.light;
//     }
//   }

//   // 监听系统亮度变化（如用户手动切换系统深色模式）
//   void _listenSystemBrightnessChange() {
//     SystemChannels.lifecycle.setMessageHandler((msg) async {
//       // 应用从后台返回/系统模式变化时，更新亮度
//       await _initSystemBrightness();
//       return null;
//     });
//   }

//   // 根据 appThemeMode 计算当前生效的亮度
//   void _updateCurrentBrightness() {
//     if (_appThemeMode == ThemeMode.light) {
//       _currentBrightness = Brightness.light;
//     } else if (_appThemeMode == ThemeMode.dark) {
//       _currentBrightness = Brightness.dark;
//     } else {
//       // 跟随系统：使用系统亮度
//       _initSystemBrightness();
//     }
//   }

//   // 快捷判断：是否为深色模式
//   bool get isDarkMode => _currentBrightness == Brightness.dark;

//   ThemeMode get themeMode => _themeMode;

//   // 设置主题模式
//   void setThemeMode(ThemeMode mode) {
//     _themeMode = mode;
//     _appThemeMode = mode;
//     // _updateCurrentBrightness();
//     notifyListeners();
//   }

//   // 获取当前系统的实际亮度模式（浅色/深色）
//   Brightness getSystemBrightness(BuildContext context) {
//     return MediaQuery.of(context).platformBrightness;
//   }

//   // 监听系统配置变化（核心：系统切换深色/浅色时触发）
//   @override
//   void didChangePlatformBrightness() {
//     super.didChangePlatformBrightness();
//     // 如果当前主题是"跟随系统"，则通知UI刷新
//     if (_themeMode == ThemeMode.system) {
//       notifyListeners();
//     }
//   }

//   // 释放资源
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
// }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 绑定完成
  // 1. 设置状态栏背景色（仅 Android 生效，iOS 状态栏背景默认透明）
  // 初始化首次启动时间（应用启动时执行一次即可）
  // await Utils.initFirstLaunchTime();
  // 提前初始化数据库
  await Utils.init(); // 初始化工具类
  await DatabaseHelper().database;
  // 1. 获取系统原始亮度模式
  await EasyLocalization.ensureInitialized();
  // 初始化本地存储
  if (Platform.isAndroid) {
    WebViewPlatform.instance;
  }
  // 可选：读取保存的语言设置
// 禁用Release模式的调试日志

  // Locale initialLocale = const Locale('zh', ''); // 默认语言
  // if (Utils.getLanguage() != null) {
  //   final parts = Utils.getLanguage();
  //   initialLocale = Locale(parts,'');
  // }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => GitProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CountProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => UpdateProvider(),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('zh')],
        path: 'assets/lang',
        fallbackLocale: const Locale('zh'),
        startLocale: Locale(Utils.getLanguage()), // 初始语言
        child: MyApp(initialThemeMode: ThemeUtil.getThemeMode()),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({super.key, required this.initialThemeMode});
  // 提供全局主题更新方法
  // 提供全局主题更新方法

  static void refreshTheme(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setState(() {});
  }

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // 显示当前主题模式
    // Utils.showToast(context, '${ThemeUtil.getIsDark()}');
    // 显示当前主题模式
    return OKToast(
        child: ScreenUtilInit(
            designSize: const Size(360, 690),
            builder: (context, child) {
              return MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale, // 当前语言
                title: 'Gitdiary',
                theme: ThemeUtil.getAppTheme(),
                darkTheme: ThemeUtil.getAppTheme(isDark: true),
                themeMode: themeProvider.themeMode,
                // home: const Index(),
                home: const LaunchPage(),  // 启动判断页
                debugShowCheckedModeBanner: false,
                // localizationsDelegates: [
                //   GlobalMaterialLocalizations.delegate,
                //   GlobalCupertinoLocalizations.delegate,
                //   GlobalWidgetsLocalizations.delegate,
                //   FlutterQuillLocalizations.delegate,
                // ],
              );
            }));
    // return ChangeNotifierProvider(
    //     create: (context) => ThemeProvider(),
    //     child: Consumer<ThemeProvider>(builder: (context, provider, child) {
    //       // 根据当前主题模式和系统亮度，确定实际使用的主题

    //     }));
  }
}

// 启动页：判断首次启动，路由分发
class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _isLoading = true;    // 加载状态
  bool _isFirstLaunch = true;// 是否首次启动

  @override
  void initState() {
    super.initState();
    _checkLaunchStatus();    // 初始化时读取状态
  }

  // 读取首次启动状态
  Future<void> _checkLaunchStatus() async {
    final isFirst = await Utils.checkFirstLaunch();
    setState(() {
      _isFirstLaunch = isFirst;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 加载中显示占位符
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // 状态判断：首次启动→引导页，非首次→主页面
    return _isFirstLaunch ? const Introduction() : const Index();
  }
}
