import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:editor/database.dart';
import 'package:editor/page/editor/markdown_edit_page.dart';
import 'package:editor/rich/rich_edit_page.dart';
import 'package:editor/utils/file_utils.dart';
import 'package:editor/utils/utils.dart';
import 'package:editor/webview.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class CalenderPage extends StatefulWidget {
  @override
  State<CalenderPage> createState() => _CalenderPageState();
}

class _CalenderPageState extends State<CalenderPage> {
  DateTime _selectedDay = DateTime.now(); // 当前选中的日期
  DateTime _focusedDay = DateTime.now(); // 日历聚焦的日期
  final CalendarFormat _calendarFormat = CalendarFormat.week;
  List<Map<String, dynamic>> _selectedDayArticles = [];
  Set<DateTime> _articleDates = {};

  @override
  void initState() {
    super.initState();
    _loadArticlesForSelectedDay();
    _loadAllArticleDates();
  }

  // 获取所有有文章的日期（去重），用于日历标记
  Future<void> _loadAllArticleDates() async {
    final dbHelper = DatabaseHelper();
    final allArticles = await dbHelper.getAllRecords();
    final Set<DateTime> dates = {};
    for (var article in allArticles) {
      final timestamp = article['create_time'] as int;
      final dateTime = DatabaseHelper.timestampToDateTime(timestamp);
      final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
      dates.add(dateOnly);
    }

    setState(() {
      _articleDates = dates;
    });
  }

  // 日历事件加载器：返回指定日期的事件数
  List<dynamic> _getEventsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _articleDates.contains(dateOnly) ? [1] : [];
  }
  // 加载选中日期的文章
  Future<void> _loadArticlesForSelectedDay() async {
    final dbHelper = DatabaseHelper();
    final articlesMapList = await dbHelper.getArticlesByDate(_selectedDay);
    setState(() {
      _selectedDayArticles = articlesMapList.map((dynamicMap) {
        return {
          'id': dynamicMap['id'].toString(),
          'file_name': dynamicMap['file_name'] ?? '',
          'create_time': dynamicMap['create_time'].toString(),
        };
      }).toList();
    });
  }
  // 核心方法：根据当前视图格式更新日历高度动画
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 新增：设置背景色，避免白屏视觉问题
      // backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 日历组件（修复marker定位）
          TableCalendar(
            firstDay: DateTime(2020, 1, 1),
            // shouldFillViewport: true,
            lastDay: DateTime(2030, 12, 31),
            // pageJumpingEnabled: true,
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadArticlesForSelectedDay();
            },
            rowHeight: 50,
            calendarFormat: _calendarFormat,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            // onFormatChanged: _onCalendarFormatChanged,
            // headerStyle: const HeaderStyle(
            //   // formatButtonVisible: true, // 显示视图切换按钮（月/周/日）
            //   formatButtonShowsNext: false, // 只显示当前可选的视图
            //   titleCentered: true,
            //   // formatButtonDecoration: BoxDecoration(
            //   //   color: Colors.blue,
            //   //   borderRadius: BorderRadius.all(Radius.circular(8)),
            //   // ),
            //   // formatButtonTextStyle: TextStyle(color: Colors.white),
            // ),
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  // 修复：添加明确的定位属性，避免marker位置异常
                  return Positioned(
                    // bottom: -1,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // const Divider(height: 1),
          // 选中日期的文章列表（修复时间轴布局）
          
          Expanded(
            child: _selectedDayArticles.isEmpty
                ?  Center(child: Text('model_not_file'.tr()))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                    itemCount: _selectedDayArticles.length,
                    itemBuilder: (context, index) {
                      final articleMap = _selectedDayArticles[index];
                      final createTimeStamp =
                          int.tryParse(articleMap['create_time'] ?? '0') ?? 0;
                      final createTime =
                          DatabaseHelper.timestampToDateTime(createTimeStamp);
                      final timeStr = DateFormat('HH:mm').format(createTime);
                      final fileName = articleMap['file_name'] ?? 'model_not_title'.tr();
                      final isLastItem =
                          index == _selectedDayArticles.length - 1;
                      // 修复：用IntrinsicHeight约束行高，避免无限高度问题
                      return IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ========== 文章内容区 ==========
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final appDir =
                                        await FileUtils.getAppDocDir();
                                    final folderPath =
                                        path.join(appDir.path, "diary");
                                    if (path.basename(fileName).toString().split(".").last ==
                                        'md') {
                                      //  final fileName = path.basenameWithoutExtension(entity.path);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditorPage(
                                            filePath:
                                                fileName,
                                            fileName: path.basename(fileName)
                                                .toString()
                                                .split(".")
                                                .first,
                                          ),
                                        ),
                                      );
                                    } else if (path.basename(fileName)
                                            .toString()
                                            .split(".")
                                            .last ==
                                        'gtx') {
                                      // final fileName = path.basenameWithoutExtension(entity.path);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditPage(
                                            filePath:
                                                 fileName,
                                            fileName: path.basename(fileName)
                                                .toString()
                                                .split(".")
                                                .first,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      // color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      // boxShadow: [
                                      //   BoxShadow(
                                      //     color: Colors.grey.withOpacity(0.1),
                                      //     blurRadius: 4,
                                      //     offset: const Offset(0, 2),
                                      //   ),
                                      // ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 时间标签
                                        const SizedBox(height: 10),
                                        // 文章标题
                                        Expanded(
                                          child: Text(
                                            
                                            fileName.isEmpty
                                                ? 'model_not_title'.tr()
                                                : path.basename(fileName)
                                                    .toString()
                                                    .split(".")
                                                    .first,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
