import 'package:editor/index.dart';
import 'package:editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:introduction_screen/introduction_screen.dart';


// 引导页组件（Stateful用于处理状态）
class Introduction extends StatefulWidget {
  const Introduction({super.key});

  @override
  State<Introduction> createState() => _IntroductionState();
}

class _IntroductionState extends State<Introduction> {
  // 引导页全局Key，用于内部状态控制
  final _introKey = GlobalKey<IntroductionScreenState>();

  // 引导页结束回调：标记完成并跳转主页面
  Future<void> _onIntroDone() async {
    await Utils.setIntroCompleted();  // 存储非首次启动状态
    if (mounted) {
      // 替换路由，禁止返回引导页
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Index()),
      );
    }
  }

  // 构建单页图片（统一样式）
  Widget _buildIntroImage(String assetName) {
    return Image.asset('assets/images/$assetName', width: 500);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));
    // 统一页面样式配置
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,color: Colors.amber),
      bodyTextStyle: TextStyle(fontSize: 16, height: 1.8),
      imagePadding: EdgeInsets.only(top: 60),
      imageAlignment:  Alignment.center,
      imageFlex: 4,
      pageColor: Colors.white,
    );

    // 引导页列表（可按需增删页面）
    final introPages = [
      PageViewModel(
        title: "欢迎使用Gitdiary",
        body: "首次打开，快速了解核心功能\n高性能 跨平台 笔记软件\n内置富文本和Markdown两种格式",
        image: _buildIntroImage('icon.png'),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Markdown本地编辑",
        body: "支持代码高亮 数学公式 流程图 甘特图等\n",
        image: _buildIntroImage('a.png'),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Vditor",
        body: "内置多款Markdown渲染引擎\n 更有Vditor即时渲染的加持",
        image: _buildIntroImage('b.png'),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "基于网页富文本编辑",
        body: "能够实时编辑内容可见可得 移动端友好 ",
        image: _buildIntroImage('c.png'),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "多种同步备份功能",
        body: "Git和Webdav还有本地备份\n 完成引导，解锁全部功能",
        image: _buildIntroImage('d.png'),
        decoration: pageDecoration,
      ),
    ];

    return IntroductionScreen(
      globalBackgroundColor:Colors.white,
      key: _introKey,
      pages: introPages,
      // 基础按钮配置
      showSkipButton: true,  // 显示跳过按钮
      showNextButton: true,  // 显示下一页按钮
      showBackButton: false, // 隐藏返回按钮
      // 按钮文本/图标
      skip: const Text("跳过", style: TextStyle(color: Colors.grey)),
      next: const Icon(Icons.arrow_forward_ios, size: 16,color: Colors.black,),
      done: const Text("完成", style: TextStyle(fontWeight: FontWeight.w600,color: Colors.black)),
      // 回调函数
      onSkip: _onIntroDone,   // 点击跳过：直接结束引导
      onDone: _onIntroDone,   // 点击完成：结束引导
      // 指示器样式自定义
      dotsDecorator: const DotsDecorator(
        size: Size(8, 8),
        activeSize: Size(16, 8),
        activeColor: Colors.red,
        color: Colors.grey,
        spacing: EdgeInsets.symmetric(horizontal: 4),
      ),
      // 全局按钮样式
      baseBtnStyle: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}
