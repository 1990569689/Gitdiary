import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/page/backups/webdav.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:editor/widget/dialog_widget.dart';
import 'package:editor/widget/switch_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class MePage extends StatefulWidget {
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  // 显示错误提示弹窗
  Map<String, dynamic> config = Utils.getGithubUserConfig();
//  'name': _prefs.getString('github_name') ?? '登录账号',
//       'sign': _prefs.getString('github_sign') ?? '未登录',
//       'avatar': _prefs.getString('github_avatar') ?? '',
//       'company': _prefs.getString('github_company') ?? '',
//       'blog': _prefs.getString('github_blog') ?? '',
//       'location': _prefs.getString('github_location') ?? '',
//       'email': _prefs.getString('github_email') ?? '',
//       'following': _prefs.getString('github_following') ?? '',
//       'followers': _prefs.getString('github_followers') ?? '',
//       'public_repos': _prefs.getString('github_public_repos') ?? '',
//       'public_gists': _prefs.getString('github_public_gists') ?? '',

  String _name = "";
  String _sign = "";
  String _avatar = "";
  String _company = "";
  String _blog = "";
  String _location = "";
  String _email = "";
  String _following = "";
  String _followers = "";
  String _public_repos = "";
  String _public_gists = "";

  @override
  void initState() {
    super.initState();
    _name = config['name']!;
    _sign = config['sign']!;
    _avatar = config['avatar']!;
    _company = config['company']!;
    _blog = config['blog']!;
    _location = config['location']!;
    _email = config['email']!;
    _following = config['following']!;
    _followers = config['followers']!;
    _public_repos = config['public_repos']!;
    _public_gists = config['public_gists']!;

    // 计算缓存大小
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.search),
          //   onPressed: () {},
          // ),
        ],
        flexibleSpace: Container(
          width: double.infinity,
        ),

        title: Text('my_info'.tr()),
        centerTitle: true,
        // elevation: 1,
        // 移动端显示AppBar，桌面/平板端可以隐藏或调整
        //automaticallyImplyLeading: !useNavigationRail,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          // 适配iOS/Android：iOS默认回弹，Android需自定义
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        children: [
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: ListTile(
              subtitle: Text(
                maxLines: 10,
                _sign,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.5,
                    textBaseline: TextBaseline.alphabetic,
                    overflow: TextOverflow.ellipsis),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(_name),
              leading: _avatar.isNotEmpty
                  ? CircleAvatar(
                      radius: 40,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _avatar,
                          fit: BoxFit.cover, // 确保图片覆盖整个容器
                          alignment: Alignment.center, // 确保图片居中
                          // 加载中占位
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          // 加载失败占位
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                      ),
                    )
                  : Image.asset('assets/images/github.png',
                      color: Colors.grey, width: 60, height: 60),
              onTap: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => const LoginPage(),
                //   ),
                // );
              },
            ),
          ),
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _company,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("company".tr()),
                  leading: Icon(Icons.business, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _blog,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("blog".tr()),
                  leading: Icon(Icons.link, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _location,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("location".tr()),
                  leading: Icon(Icons.location_on, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _email,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("email".tr()),
                  leading: Icon(Icons.email, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _following,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("following".tr()),
                  leading: Icon(Icons.star, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _followers,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("followers".tr()),
                  leading: Icon(Icons.people, color: Colors.grey),
                ),
                Divider(
                  height: 0.2,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.2),
                ),
                ListTile(
                  subtitle: Text(
                    maxLines: 10,
                    _public_repos,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                        textBaseline: TextBaseline.alphabetic,
                        overflow: TextOverflow.ellipsis),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text("public_repos".tr()),
                  leading: Icon(Icons.public, color: Colors.grey),
                ),
              ],
            ),
          ),
          GestureDetector(
              onTap: () {
                Utils.saveGithubConfig(owner: "", token: "");
                Utils.saveGithubUserConfig(
                    name: "登录账号",
                    sign: " 未登录",
                    avatar: "",
                    company: "",
                    blog: "",
                    location: "",
                    email: "",
                    following: "",
                    followers: "",
                    public_repos: "",
                    public_gists: "");
                Navigator.pop(context, true);
              },
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "logout".tr(),
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ))
          // 功能列表：关于我们（占位）
        ],
      ),
    );
  }
}
