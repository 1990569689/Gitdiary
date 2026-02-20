import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/webview.dart';
import 'package:flutter/widgets.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // 显示错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('tip'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
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

        title: Text('about_us'.tr()),
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
          // 顶部个人信息卡片
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Container(
                //   width: 80,
                //   height: 80,
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(40),
                //   ),
                //   child: Image.asset("assets/images/star.png",
                //       width: 40, height: 40),
                // ),
                const SizedBox(height: 20),
                Image.asset("assets/images/icon.png", width: 80, height: 80),
                SizedBox(height: 10),
                Text(
                  "app_name".tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "V1.0.2",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 功能列表：清空缓存
          Divider(
            thickness: 0.5,
            height: 1,
            indent: 60,
            endIndent: 60,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 1),
            child: ListTile(
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              title: Text(
                'about_official_website'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey,
                ),
              ),
              onTap: () {
                // 跳转到设置页面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => WebViewPage(
                            url: "https://www.pgyer.com/gitnotes",
                            title: "about_official_website".tr(),
                          )),
                );
              },
            ),
          ),
          Divider(
            thickness: 0.5,
            height: 1,
            indent: 60,
            endIndent: 60,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 1),
            child: ListTile(
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              title: Text(
                'about_update_log'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey,
                ),
              ),
              onTap: () {
                // 跳转到设置页面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => WebViewPage(
                            url: "",
                            title: 'about_update_log'.tr(),
                          )),
                );
              },
            ),
          ), // 功能列表：清空缓存
          Divider(
            thickness: 0.5,
            height: 1,
            indent: 60,
            endIndent: 60,
          ),
          // 功能列表：关于我们（占位）
        ],
      ),
    );
  }
}
