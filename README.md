<div align="center">
    <img width="200" height="200" src="./images/logo.jpg">
</div>
<h1 align="center" style="border-bottom: none">
    <b>
        <a href="https://github.com/1990569689/Gitdiary"> ⭐️  Gitdiary ⭐️ <br></a><br>
    </b>
</h1>

<p align="center"><a href="README.zh.md">简体中文</a> | <a href="./images/README_EN.md">English</a></p>
<p align="center">
Gitdiary 是一个全平台Markdown和富文本日记事应用，使用Flutter开发。
</p>
<div align="center">
  <img src="https://img.shields.io/github/stars/1990569689/Gitdiary" alt="GitHub Repo stars">
  <img src="https://img.shields.io/github/repo-size/1990569689/Gitdiary" alt="GitHub repo size">
  <img src="https://img.shields.io/github/downloads/1990569689/Gitdiary/total" alt="GitHub all releases">
  <img src="https://img.shields.io/badge/Flutter-3.22.0-blue.svg" alt="Flutter Version">
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-brightgreen.svg" alt="Supported Platforms">
  <img src="https://img.shields.io/github/license/1990569689/Gitdiary.svg" alt="License">
  <img src="https://img.shields.io/github/v/release/1990569689/Gitdiary?display_name=tag" alt="Release Version">
</div>
<br>
<div align="center">
  <strong>一站式移动端 Markdown和富文本笔记协作利器</strong>
  <p>本地自由创作，云端无缝协作的全流程富文本笔记解决方案</p>
</div>
<p align="center"><img src="./images/1.jpg" alt="FlutterUnit App"  /></p>
<p align="center"><img src="./images/2.jpg" alt="FlutterUnit App"  /></p>

## 🌟 项目介绍

Gitdiary 是一款基于 Flutter 3.22.0 开发的跨平台 Markdown/富文本编辑工具，专为创作者、开发者、学生和研究者打造。融合了沉浸式编辑体验、多端数据同步、AI 智能创作和全球化适配能力，让笔记创作更高效、更自由。

## ✨ 核心功能

### 📝 沉浸式编辑体验
- 支持**完整 Markdown 语法**及扩展语法（表格、脚注、代码块语法高亮）
- 自定义文本颜色、字体样式、排版规则，打造个性化笔记
- 白天/夜间主题无缝切换，适配不同使用场景，降低长时间创作的视觉疲劳
- **富文本与 Markdown 双模式编辑**，满足多样化书写需求


#### 📈 功能预览

|夜间模式|文本编辑|
|---|---|
|![分类示例](./images/b.png)|![分类示例](./images/a.png)|
|富文本渲染|个人中心|
|![分类示例](./images/c.png)|![分类示例](./images/d.png)|



### ☁️ 多端数据同步与备份
- **GitHub 深度集成**：账号登录、一键提交笔记至仓库、下载开源笔记资源
- **三备份保障**：GitHub 同步 + WebDAV 云端备份，支持本地文件导入导出
- **GitHub 图床联动**：图片一键上传，自动嵌入链接，解决跨平台显示问题
- 版本管理：依托 Git 实现笔记的版本追溯与恢复

### 🤖 AI 赋能创作
- 对接 OpenAI 系列 AI 接口，支持流式问答与内容辅助创作
- 应用场景：大纲生成、内容润色、代码解释、疑难解答
- 实时响应，大幅提升创作效率

### 🌐 全球化适配
- 多语言切换功能，满足不同地区用户使用习惯
- 遵循 Material Design 设计规范，交互体验统一

### 🎯 适用人群
- **开发者**：编写技术文档、注释、开源项目 README，实现版本管理与协作
- **内容创作者**：撰写博客、读书笔记、思维导图，自定义样式打造个性化笔记
- **学生/研究者**：整理学习笔记、论文提纲，多重备份确保资料安全留存

## 🧪 开发计划

### 已完成

- ✅ 富文本编辑器，webview渲染，支持粗体，斜体，下划线，角标，删除线，无序列表，有序列表，引用，代码，checkbox，图片，视频，音频，超链接....，支持自定义HTML
- ✅ GitHub登陆，提交笔记到GitHub，拉取GitHub笔记文件，上传图片到GitHub
- ✅ Markdown编辑器，支持基本的markdown操作，数学公式，代码，甘特图，mermaid，gantt，katex，化学公式，多款渲染引擎，集成vditor
- ✅ webdav备份，本地备份导入与导出
- ✅ 对接 OpenAI 系列 AI 接口，支持流式问答与内容辅助创作
- ✅ 多语言切换功能，满足不同地区用户使用习惯
- ✅ 白天和黑夜模式切换
- ✅ Markdown编辑器设置
- ✅ 使用频率热力图
- ✅ 快捷指令集成
- ✅ 批量编辑功能


## 🚀 快速开始

### 环境要求
- Flutter SDK 3.22.0 及以上
- Dart SDK 3.4.0 及以上
- Android Studio / VS Code (带 Flutter 插件)

项目结构参考
```
lib/
├── generators/        # markdown自定义解析文件
├── page/              # 页码文件
├── rich/              # 富文本编辑器
├── utils/             # 工具类
├── widget/            # 自定义组件
├── main.dart          # 主文件
├── chat.dart          # 对接大模型文件
├── databse.dart       # 数据库文件
├── introduction.dart  # APP引导文件
├── provider.dart      # 状态管理文件
├── theme.dart         # 主题文件
├── update.dart        # 更新文件
├── main.dart          # 主文件
├── webview.dart       # webview文件
└── index.dart         # 导航
```

### 安装与运行
```bash
# 克隆仓库
git clone https://github.com/1990569689/Gitdiary.git

# 进入项目目录
cd gitdiary

# 获取依赖
flutter pub get

# 运行项目
flutter run

# 打包 APK (Android)
flutter build apk --release

# 打包 IPA (iOS)
flutter build ios --release
```

### Star History

<a href=""> 
  <picture> 
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=1990569689/Gitdiary&type=date&theme=dark&legend=top-left" /> 
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=1990569689/Gitdiary&type=date&legend=top-left" /> 
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=1990569689/Gitdiary&type=date&legend=top-left" /> 
  </picture> 
 </a >



