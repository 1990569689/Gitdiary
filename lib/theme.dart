import 'package:editor/main.dart';
import 'package:editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

class ThemeUtil {
  static bool _isDark = false;
  // 获取应用主题
  static ThemeData getAppTheme({bool isDark = false}) {
    final themeMode = Utils.getThemeMode();
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //  Provider.of<ThemeProvider>(context, listen: false)
    //                           .refresh();
    //   });

    // 亮色主题
    if (themeMode == 1) {
      _isDark = false;
      return _buildLightTheme();
    }
    // 暗色主题
    else if (themeMode == 2) {
      _isDark = true;
      return _buildDarkTheme();
    } else if (themeMode == 0) {
      if (getSystemBrightness() == Brightness.dark) {
        _isDark = true;
        return _buildDarkTheme();
      } else {
        _isDark = false;
        return _buildLightTheme();
      }
// 跟随系统（默认亮色）
      // if (isDark) {
      //   // _isDark = false;

      // } else {
      //   // _isDark = false;
      //   return _buildLightTheme();
      // }
    }
    return _buildLightTheme();
  }

  // 安全获取系统亮度的方法
  static Brightness? getSystemBrightness() {
    try {
      // 方案1：使用 ?. 安全访问，避免空值断言 !
      final window = WidgetsBinding.instance.window;
      final brightness = window.platformBrightness;

      // 兜底：如果获取失败，返回默认亮度（比如亮色）
      return brightness ?? Brightness.light;
    } catch (e) {
      // 捕获所有异常，避免崩溃
      
      // 兜底返回默认亮度
      return Brightness.light;
    }
  }

  static bool getIsDark() {
    return _isDark;
  }

  // 构建亮色主题
  static ThemeData _buildLightTheme() {
    _isDark = false;
    return ThemeData(
      // primaryTextTheme: TextTheme(),s
      // 修复后的TextButtonTheme配置
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          // 正确方式：用MaterialStateProperty.all包裹TextStyle
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(
                color: Colors.black, fontSize: 16 // 可选：补充字体大小，让样式更完整
                ),
          ),
          // 可选：去除TextButton默认的点击水波纹背景
          backgroundColor: MaterialStateProperty.all<Color>(Colors.transparent),
          // 可选：去除默认的内边距
          padding: MaterialStateProperty.all<EdgeInsets>(EdgeInsets.all(2)),
        ),
      ),

      // primaryTextTheme: TextTheme(),
      inputDecorationTheme: InputDecorationTheme(),
      dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          contentTextStyle: TextStyle(color: Colors.black)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        textStyle: TextStyle(color: Colors.black),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color.fromARGB(255, 231, 117, 117),
      ),
      cardTheme:CardTheme(
        color: Colors.grey.withOpacity(0.1),
      ) ,
      brightness: Brightness.light,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF3182CE)),
      ),
      appBarTheme: AppBarTheme(
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
      ),
      useMaterial3: true,
      primaryColor: Color.fromARGB(255, 231, 117, 117),
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      cardColor: const Color(0xFFF7FAFC),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF2D3748)),
        bodyMedium: TextStyle(color: Color(0xFF4A5568)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3182CE),
        ),
      ), // BottomNavigationBar配置
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        landscapeLayout: BottomNavigationBarLandscapeLayout.linear,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: const Color(0xFFA0AEC0),
        selectedLabelStyle: TextStyle(fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        elevation: 4,
      ),
      // 文本样式
    );
  }

  // 构建深色主题（根据细分类型）
  static ThemeData _buildDarkTheme() {
    _isDark = true;
    Color primaryColor = Color.fromARGB(255, 255, 255, 255);
    Color appBarColor;
    Color bottomNavColor;
    Color scaffoldColor;
    Color cardColor;
    // 根据深色模式类型配置不同配色
    scaffoldColor = Colors.black;
    cardColor = const Color(0xFF121212);
    appBarColor = const Color(0xFF000000);
    bottomNavColor = const Color(0xFF000000);
    return ThemeData(
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color.fromARGB(255, 59, 59, 59),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.black,
        textStyle: TextStyle(color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarColor,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Color.fromARGB(255, 231, 117, 117),
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
        bodyMedium: TextStyle(color: Color(0xFFE2E8F0)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63B3ED),
        ),
      ), // BottomNavigationBar配置（关键：暗色背景+白色图标）
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        landscapeLayout: BottomNavigationBarLandscapeLayout.spread,
        type: BottomNavigationBarType.fixed,
        backgroundColor: bottomNavColor,
        selectedItemColor: primaryColor, // 选中项高亮色
        unselectedItemColor: const Color(0xFFA0AEC0), // 未选中项灰色
        selectedLabelStyle: const TextStyle(fontSize: 12, color: Colors.white),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, color: Color(0xFFA0AEC0)),
        elevation: 4,
      ),
    );
  }

  // 应用主题模式到MaterialApp
  static ThemeMode getThemeMode() {
    final mode = Utils.getThemeMode();
    switch (mode) {
      case 0:
        return ThemeMode.system;
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
