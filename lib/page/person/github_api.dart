import 'dart:convert';
import 'dart:io';

import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class GitHubFileDownloader {
  /// GitHub API基础地址
  static const String _githubApiBase = 'https://api.github.com';

  /// 下载GitHub仓库所有文件（逐个下载，非整包）
  /// [owner]：仓库所有者（如：flutter）
  /// [repo]：仓库名称（如：flutter）
  /// [branch]：分支名称（默认：main）
  /// [token]：私有仓库需传GitHub Token，公有仓库可传null
  /// [onProgress]：下载进度回调（已下载文件数/总文件数）
  static Future<bool> downloadRepoFiles({
    required String owner,
    required String repo,
    String branch = 'main',
    String? token,
    Function(int, int)? onProgress,
  }) async {
    Dio dio = Dio();
    // 配置请求头（私有仓库需Token）
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'token $token';
    }
    dio.options.headers['Accept'] = 'application/vnd.github.v3+json';

    try {
      // 1. 获取应用Documents目录，创建仓库根目录
      final appDir = await FileUtils.getAppDocDir();
      final folderPath = path.join(appDir.path, "diary");

      final repoRootDir =
          Directory(path.join(folderPath + "/Github/", '$repo-$branch'));
      if (repoRootDir.existsSync()) {
        repoRootDir.deleteSync(recursive: true); // 清空旧文件
      }
      repoRootDir.createSync(recursive: true);

      // 2. 递归获取仓库所有文件列表
      List<Map<String, dynamic>> allFiles = [];
      await _fetchRepoFiles(
        dio: dio,
        owner: owner,
        repo: repo,
        branch: branch,
        path: '', // 从根目录开始遍历
        allFiles: allFiles,
      );

      if (allFiles.isEmpty) {
        print('仓库中未找到可下载的文件');
        return false;
      }

      // 3. 逐个下载文件
      int downloadedCount = 0;
      final totalFiles = allFiles.length;
      for (var file in allFiles) {
        final filePath = file['path'] as String; // 仓库中的相对路径
        final downloadUrl = file['download_url'] as String?;

        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadedCount++;
          onProgress?.call(downloadedCount, totalFiles);
          continue;
        }

        // 拼接本地文件路径
        final localFilePath = path.join(repoRootDir.path, filePath);
        final localFileDir = Directory(path.dirname(localFilePath));
        // 确保文件所在目录存在
        if (!localFileDir.existsSync()) {
          localFileDir.createSync(recursive: true);
        }

        // 下载文件到本地
        await dio.download(
          downloadUrl,
          localFilePath,
          options: Options(responseType: ResponseType.bytes),
        );

        // 更新进度
        downloadedCount++;
        onProgress?.call(downloadedCount, totalFiles);
      }

      print('所有文件下载完成，存储路径：${repoRootDir.path}');
      return true;
    } on DioException catch (e) {
      print('GitHub API/下载错误：${e.response?.statusCode} - ${e.message}');
      return false;
    } catch (e) {
      print('文件处理错误：$e');
      return false;
    }
  }

  /// 递归获取仓库指定路径下的所有文件
  static Future<void> _fetchRepoFiles({
    required Dio dio,
    required String owner,
    required String repo,
    required String branch,
    required String path,
    required List<Map<String, dynamic>> allFiles,
  }) async {
    // GitHub API：获取指定路径下的内容
    final url = '$_githubApiBase/repos/$owner/$repo/contents/$path?ref=$branch';
    final response = await dio.get(url);
    final List<dynamic> contents = response.data;

    for (var item in contents) {
      final Map<String, dynamic> content = item as Map<String, dynamic>;
      final String type = content['type'] as String;

      if (type == 'file') {
        // 是文件，加入列表
        allFiles.add(content);
      } else if (type == 'dir') {
        // 是目录，递归遍历
        final String dirPath = content['path'] as String;
        await _fetchRepoFiles(
          dio: dio,
          owner: owner,
          repo: repo,
          branch: branch,
          path: dirPath,
          allFiles: allFiles,
        );
      }
    }
  }
}

class GithubApi {
  static Map githubManageConfigMap = {
    'private': false,
    'has_issues': true,
    'has_projects': true,
    'has_wiki': true,
    'auto_init': true,
    'is_template': false,
  };

  resetgithubManageConfigMap() {
    githubManageConfigMap = {
      'private': false,
      'has_issues': true,
      'has_projects': true,
      'has_wiki': true,
      'auto_init': true,
      'gitignore_template': 'None',
      'license_template': 'None',
      'is_template': false,
    };
  }
  //  if (descriptionController.text.isNotEmpty) {
  //                   githubManageConfigMap['description'] = descriptionController.text;
  //                 }
  //                 if (homepageController.text.isNotEmpty) {
  //                   githubManageConfigMap['homepage'] = homepageController.text;
  //                 }
  //                 githubManageConfigMap['name'] = repoNameController.text;

  //                 if (githubManageConfigMap['gitignore_template'] == 'None') {
  //                   githubManageConfigMap.remove('gitignore_template');
  //                 }
  //                 if (githubManageConfigMap['license_template'] == 'None') {
  //                   githubManageConfigMap.remove('license_template');
  //                 }

  static String get githubOwner => Utils.getGithubConfig()['owner']!;
  static String get githubToken => Utils.getGithubConfig()['token']!;

  static const String baseUrl = 'https://api.github.com';

  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      //  API：获取指定目录下的文件列表
      final apiUrl = 'https://api.github.com/users/${githubOwner}';
      final dio = Dio();
      final response = await dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Authorization': githubToken,
            'Accept': 'application/vnd.github+json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      // 解析响应：过滤出图片文件，提取download_url
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("失败：${response.statusMessage}");
      }
    } catch (e) {
      throw Exception("出错：$e");
    }
  }

  static Future<Map<String, dynamic>> isFileExist(
      {required String fileName, required String githubRepo}) async {
    try {
      String host =
          'https://api.github.com/repos/$githubOwner/$githubRepo/contents/$fileName';
      final dio = Dio();
      final response = await dio.get(
        host,
        options: Options(
          headers: {
            'Authorization': 'Bearer $githubToken',
            'Accept': 'application/vnd.github+json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200) {
        return {"isExist": true, "sha": "${response.data["sha"]}"};
      } else {
        return {"isExist": false, "sha": ""};
      }
    } catch (e) {
      return {"isExist": false, "sha": ""};
    }
  }

  static Future<Map<String, dynamic>> isRepoExist(
      {required String githubRepo}) async {
    try {
      String host = 'https://api.github.com/repos/$githubOwner/$githubRepo';
      final dio = Dio();
      final response = await dio.get(
        host,
        options: Options(
          headers: {
            'Authorization': 'Bearer $githubToken',
            'Accept': 'application/vnd.github+json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200) {
        return {"isExist": true, "sha": "${response.data["sha"]}"};
      } else {
        return {"isExist": false, "sha": ""};
      }
    } catch (e) {
      return {"isExist": false, "sha": ""};
    }
  }

  // 将图片文件转换为Base64编码（Gitee API要求）
  static Future<String> _imageToBase64(File imageFile) async {
    // 读取图片字节
    final bytes = await imageFile.readAsBytes();
    // 转换为Base64字符串（不需要带data:image/jpeg;base64,前缀）
    return base64Encode(bytes);
  }

  static Future<String> uploadImage(File imageFile) async {
    // 验证配置
    try {
      // 1. 处理文件名：用时间戳+原后缀，避免重复覆盖
      final fileExt = path.extension(imageFile.path).toLowerCase();
      final fileName = "${DateTime.now().millisecondsSinceEpoch}$fileExt";
      // Gitee仓库中的文件路径（自动创建images目录）
      final giteeFilePath = "images/$fileName";

      // 2. 将图片转Base64
      final base64Content = await _imageToBase64(imageFile);

      // 3. 构造Gitee API请求
      final apiUrl =
          "https://api.github.com/repos/${githubOwner}/${Utils.getGitConfig()['repo']!}/contents/${Utils.getGitConfig()['image']!}/${fileName}";

      final dio = Dio();
      final response = await dio.put(
        apiUrl,
        data: {
          "message": "Upload image from Gitdiary", // 提交说明
          "content": base64Content, // Base64编码的图片内容
          "committer": {
            "name": githubOwner,
            "email": githubOwner + "@github.com"
          }, // 仓库分支
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer  $githubToken',
            'Accept': 'application/vnd.github+json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 解析响应，返回Raw链接
        final data = response.data;
        return data['content']['download_url'];
      } else {
        throw Exception("上传失败：${response.statusCode} ${response.data}");
      }
    } catch (e) {
      throw Exception("GitHub上传失败：$e");
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
      {required String fileName,
      required String content,
      required String githubRepo,
      required String branch,
      required String message}) async {
    Map<String, dynamic> res =
        await isFileExist(fileName: fileName, githubRepo: githubRepo);
    if (res["isExist"]) {
      try {
        final apiUrl =
            "https://api.github.com/repos/${githubOwner}/${githubRepo}/contents/$fileName";
        final dio = Dio();
        final response = await dio.put(
          apiUrl,
          data: {
            "message": message, // 提交说明
            "content": base64Encode(utf8.encode(content)), // Base64编码的图片内容
            "sha": res["sha"],
            "committer": {
              "name": githubOwner,
              "email": githubOwner + "@github.com"
            }, // 仓库分支
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $githubToken',
              'Accept': 'application/vnd.github+json',
            },
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          // 解析响应，返回Raw链接
          final data = response.data;
          return data;
        } else {
          throw Exception("上失败：${response.statusCode} ${response.data}");
        }
      } catch (e) {
        throw Exception("GitHub上失败：$e");
      }
    } else {
      try {
        final apiUrl =
            "https://api.github.com/repos/${githubOwner}/${githubRepo}/contents/$fileName";
        final dio = Dio();
        final response = await dio.put(
          apiUrl,
          data: {
            "message": message, // 提交说明
            "content": base64Encode(utf8.encode(content)), // Base64编码的图片内容
            "committer": {
              "name": githubOwner,
              "email": githubOwner + "@github.com"
            }, // 仓库分支
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $githubToken',
              'Accept': 'application/vnd.github+json',
            },
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          // 解析响应，返回Raw链接
          final data = response.data;
          return data;
        } else {
          throw Exception("上传失败：${response.statusCode} ${response.data}");
        }
      } catch (e) {
        throw Exception("GitHub上传失败：$e");
      }
    }
    // 验证配置
  }

  Future<bool> deleteFile(
      dynamic file, String githubRepo, String branch) async {
    final apiUrl =
        'https://api.github.com/repos/${githubOwner}/${githubRepo}/contents/${file.path}';
    try {
      // 构建删除请求体
      final dio = Dio();
      final response = await dio.delete(
        apiUrl,
        data: {
          'message': 'deleted',
          'sha': file.sha // 仓库分支
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer  $githubToken',
            'Accept': 'application/vnd.github+json',
          },
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception("删除失败：${response.statusCode} ${response.data}");
      }
    } catch (e) {
      throw Exception("GitHub删除失败：$e");
    }
  }

  getReposList() async {
    try {
      List reposList = [];
      String host = 'https://api.github.com/user/repos';
      int page = 0;

      // 构建删除请求体
      final dio = Dio();
      while (true) {
        page = page + 1;
        var response = await dio.get(host,
            queryParameters: {'page': page, 'per_page': 10},
            options: Options(
              headers: {
                'Authorization': githubToken,
                'Accept': 'application/vnd.github+json',
              },
            ));
        if (response.statusCode != 200) {
          return ['failed'];
        }
        if (response.data.length <= 0) {
          return ['success', reposList];
        }
        reposList.addAll(response.data);
      }
    } catch (e) {
      return [e.toString()];
    }
  }

  //创建仓库
  static Future<bool> createRepo(String name, String description) async {
    githubManageConfigMap['description'] = description;
    githubManageConfigMap['name'] = name;
    try {
      String host = 'https://api.github.com/user/repos';
      final dio = Dio();
      final response = await dio.post(
        host,
        data: {
          'name': name,
          'description': description,
          'private': false,
          'auto_init': true,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer  $githubToken',
            'Accept': 'application/vnd.github+json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

// getReposList() async {
//     try {
//       Map configMap = await getConfigMap();
//       List reposList = [];
//       String host = 'https://api.github.com/user/repos';
//       int page = 0;
//       BaseOptions baseoptions = setBaseOptions()
//         ..headers = {
//           'Authorization': configMap['token'],
//           'Accept': 'application/vnd.github+json',
//         };
//       Dio dio = Dio(baseoptions);
//       while (true) {
//         page = page + 1;
//         var response = await dio.get(host, queryParameters: {'page': page, 'per_page': 10});
//         if (response.statusCode != 200) {
//           return ['failed'];
//         }
//         if (response.data.length <= 0) {
//           return ['success', reposList];
//         }
//         reposList.addAll(response.data);
//       }
//     } catch (e) {
//       flogErr(e, {}, "GithubManageAPI", "getReposList");
//       return [e.toString()];
//     }
//   }

//   getOtherReposList(String username) async {
//     try {
//       Map configMap = await getConfigMap();
//       List reposList = [];
//       String host = 'https://api.github.com/users/$username/repos';
//       int page = 0;
//       BaseOptions baseoptions = setBaseOptions();
//       baseoptions.headers = {
//         'Authorization': configMap['token'],
//         'Accept': 'application/vnd.github+json',
//       };
//       Dio dio = Dio(baseoptions);

//       while (true) {
//         page = page + 1;
//         var response = await dio.get(host, queryParameters: {'page': page, 'per_page': 10});
//         if (response.statusCode != 200) {
//           return ['failed'];
//         }
//         if (response.data.length > 0) {
//           reposList.addAll(response.data);
//         } else {
//           return ['success', reposList];
//         }
//       }
//     } catch (e) {
//       flogErr(
//           e,
//           {
//             'username': username,
//           },
//           "GithubManageAPI",
//           "getOtherReposList");
//       return [e.toString()];
//     }
//   }

  //获取仓库根目录sha
  // getRootDirSha(String username, String repoName, String branch) async {
  //   try {
  //     Map configMap = await getConfigMap();
  //     String host = 'https://api.github.com/repos/$username/$repoName/branches/$branch';
  //     return await _makeRequest(
  //       url: host,
  //       method: 'GET',
  //       headers: {
  //         'Authorization': configMap['token'],
  //         'Accept': 'application/vnd.github+json',
  //       },
  //       onSuccess: (response) => ['success', response.data['commit']['commit']['tree']['sha']],
  //       checkSuccess: (response) => response.statusCode == 200,
  //       callFunction: 'getRootDirSha',
  //     );
  //   } catch (e) {
  //     flogErr(
  //         e,
  //         {
  //           'username': username,
  //           'repoName': repoName,
  //           'branch': branch,
  //         },
  //         "GithubManageAPI",
  //         "getRootDirSha");
  //     return [e.toString()];
  //   }
  // }

  // getRepoDirList(String username, String repoName, String sha) async {
  //   try {
  //     Map configMap = await getConfigMap();
  //     String host = 'https://api.github.com/repos/$username/$repoName/git/trees/$sha';
  //     return await _makeRequest(
  //       url: host,
  //       method: 'GET',
  //       headers: {
  //         'Authorization': configMap['token'],
  //         'Accept': 'application/vnd.github+json',
  //       },
  //       onSuccess: (response) => ['success', response.data['tree']],
  //       checkSuccess: (response) => response.statusCode == 200,
  //       callFunction: 'getRepoDirList',
  //     );
  //   } catch (e) {
  //     flogErr(
  //         e,
  //         {
  //           'username': username,
  //           'repoName': repoName,
  //           'sha': sha,
  //         },
  //         "GithubManageAPI",
  //         "getRepoDirList");
  //     return [e.toString()];
  //   }
  // }

  // isDirEmpty(String username, String repoName, String bucketPrefix) async {
  //   try {
  //     Map configMap = await getConfigMap();
  //     String host = 'https://api.github.com/repos/$username/$repoName/contents/$bucketPrefix';
  //     BaseOptions baseoptions = setBaseOptions();
  //     baseoptions.headers = {
  //       'Authorization': configMap['token'],
  //       'Accept': 'application/vnd.github+json',
  //     };
  //     Dio dio = Dio(baseoptions);
  //     var response = await dio.get(host);
  //     if (response.statusCode == 200) {
  //       return response.data.isEmpty ? ['empty'] : ['not empty'];
  //     }
  //   } catch (e) {
  //     if (e is DioException && e.toString().contains('This repository is empty')) {
  //       return ['empty'];
  //     }
  //     flogErr(
  //         e,
  //         {
  //           'username': username,
  //           'repoName': repoName,
  //           'bucketPrefix': bucketPrefix,
  //         },
  //         'GithubManageAPI',
  //         'isDirEmpty');
  //     return ['error'];
  //   }
  // }

  // // //获取仓库文件内容
  // getRepoFileContent(String username, String repoName, String filePath) async {
  //   try {
  //     Map configMap = await getConfigMap();
  //     String host = 'https://api.github.com/repos/$username/$repoName/contents/$filePath';
  //     return await _makeRequest(
  //       url: host,
  //       method: 'GET',
  //       headers: {
  //         'Authorization': configMap['token'],
  //         'Accept': 'application/vnd.github+json',
  //       },
  //       onSuccess: (response) => ['success', response.data],
  //       checkSuccess: (response) => response.statusCode == 200,
  //       callFunction: 'getRepoFileContent',
  //     );
  //   } catch (e) {
  //     flogErr(
  //         e,
  //         {
  //           'username': username,
  //           'repoName': repoName,
  //           'filePath': filePath,
  //         },
  //         'GithubManageAPI',
  //         'getRepoFileContent');
  //     return [e.toString()];
  //   }
  // }
}
