// GitHub 图片模型
class UpdateInfoModel {
  final String version; // 文件名
  final String title; // 下载链接
  final String content; // 仓库路径
  final String url; // 文件大小

  UpdateInfoModel({
    required this.version,
    required this.title,
    required this.content,
    required this.url,
  });
}
