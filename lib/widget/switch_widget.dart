import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

/// 自定义精美 Switch 组件
class SwitchWidget extends StatefulWidget {
  /// 开关状态
  final bool value;

  /// 状态改变回调
  final ValueChanged<bool>? onChanged;

  /// 开启状态的渐变颜色
  final Gradient activeGradient;

  /// 关闭状态的背景色
  final Color inactiveColor;

  /// 滑块颜色
  final Color thumbColor;

  /// 滑块阴影颜色
  final Color thumbShadowColor;

  /// 开关宽度
  final double width;

  /// 开关高度
  final double height;

  /// 滑块大小
  final double thumbSize;

  /// 开启/关闭图标（可选）
  final Widget? activeIcon;
  final Widget? inactiveIcon;

  /// 是否禁用
  final bool disabled;

  const SwitchWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeGradient = const LinearGradient(
      colors: [Color(0xFF2196F3), Color(0xFF2196F3)],
    ),
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.thumbColor = Colors.white,
    this.thumbShadowColor = Colors.transparent,
    this.width = 60,
    this.height = 32,
    this.thumbSize = 28,
    this.activeIcon,
    this.inactiveIcon,
    this.disabled = false,
  });

  @override
  State<SwitchWidget> createState() => _SwitchWidgetState();
}

class _SwitchWidgetState extends State<SwitchWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _thumbAnimation; // 滑块位移动画
  late Animation<double> _opacityAnimation; // 图标透明度动画

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器（时长 200ms，符合原生交互节奏）
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0, // 初始状态匹配开关值
    );

    // 滑块位移动画（从左到右/从右到左）
    _thumbAnimation = Tween<double>(
      begin: 0,
      end: widget.width - widget.thumbSize,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 图标透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SwitchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 开关状态变化时，驱动动画
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 禁用状态下的透明度
    final disabledOpacity = widget.disabled ? 0.6 : 1.0;

    return Opacity(
      opacity: disabledOpacity,
      child: GestureDetector(
        // 禁用时不响应点击
        onTap: widget.disabled || widget.onChanged == null
            ? null
            : () => widget.onChanged!(!widget.value),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            // 开关轨道背景（开启时渐变，关闭时纯色）
            gradient: widget.value ? widget.activeGradient : null,
            color: widget.value ? null : widget.inactiveColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: widget.value
                    ? widget.activeGradient.colors.last.withOpacity(0.2)
                    : widget.inactiveColor.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ],
          ),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                children: [
                  // 滑块
                  Positioned(
                    left: _thumbAnimation.value,
                    top: (widget.height - widget.thumbSize) / 2,
                    child: Container(
                      width: widget.thumbSize,
                      height: widget.thumbSize,
                      decoration: BoxDecoration(
                        color: widget.thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.thumbShadowColor,
                            blurRadius: 3,
                            spreadRadius: 0.5,
                          )
                        ],
                      ),
                      child: Center(
                        child: Stack(
                          children: [
                            // 开启图标
                            Opacity(
                              opacity:
                                  widget.value ? _opacityAnimation.value : 0,
                              // child: widget.activeIcon ??
                              //     const Icon(
                              //       Icons.check,
                              //       size: 16,
                              //       color: Color(0xFF2196F3),
                              //     ),
                            ),
                            // 关闭图标
                            Opacity(
                              opacity:
                                  !widget.value ? _opacityAnimation.value : 0,
                              // child: widget.inactiveIcon ??
                              //     const Icon(
                              //       Icons.close,
                              //       size: 16,
                              //       color: Color(0xFF9E9E9E),
                              //     ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
