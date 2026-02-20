import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

/// iOS 风格加载弹窗工具类
class DialogWidget {
  static OverlayEntry? _overlayEntry; // 用于全局弹窗（可选，也可用showDialog）
  static bool _isShow = false; // 防止重复显示

  /// 显示 iOS 风格加载弹窗
  /// [context] 上下文
  /// [message] 加载提示文字（可选，不传则只显示加载动画）
  static void show({
    required BuildContext context,
    String? message,
  }) {
    if (_isShow) return;
    _isShow = true;

    showDialog(
      context: context,
      barrierDismissible: false, // 点击外部不关闭
      barrierColor: Colors.black.withOpacity(0.5), // iOS 半透明背景
      builder: (context) {
        return Center(
          child: Container(
            width: message == null ? 100 : 120, // 有无文字调整宽度
            height: message == null ? 100 : 120,
            decoration: BoxDecoration(
              color: Colors.white, // iOS 白色容器
              borderRadius: BorderRadius.circular(20), // iOS 大圆角
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // iOS 原生加载指示器
                const CupertinoActivityIndicator(
                  radius: 18, // 调整指示器大小
                  color: Colors.grey, // iOS 默认灰色
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  /// 关闭加载弹窗
  static void dismiss(BuildContext context) {
    if (_isShow) {
      Navigator.of(context).pop();
      _isShow = false;
    }
  }
}
