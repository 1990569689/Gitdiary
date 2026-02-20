// 数据库帮助类（单例模式）
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // 数据库表名和字段
  static const String tableName = 'records';
  static const String columnId = 'id';
  static const String columnFileName = 'file_name';
  static const String columnCreateTime = 'create_time'; // 存储时间戳（毫秒）

  // 初始化数据库
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

// 初始化数据库工厂（核心修复步骤）
  void initDatabaseFactory() {
    // 桌面平台（Windows/macOS/Linux）需要初始化ffi
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 关键：将全局databaseFactory设置为ffi版本
      databaseFactory = databaseFactoryFfi;
      // 初始化ffi（部分环境需要这一步）
      sqfliteFfiInit();
    }
    // 移动端（Android/iOS）无需处理，sqflite会自动初始化
  }

  // 创建数据库和表
  Future<Database> _initDatabase() async {
    initDatabaseFactory();
    final dbPath = await getDatabasesPath();
    final path = '${dbPath}database.db';

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnFileName TEXT NOT NULL,
            $columnCreateTime INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ========== 核心修改3：新增按日期查询文章的方法（核心需求） ==========
  Future<List<Map<String, dynamic>>> getArticlesByDate(DateTime date) async {
    final db = await database;
    // 计算目标日期的开始时间戳（00:00:00）和结束时间戳（23:59:59.999）
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final startTimestamp = startOfDay.millisecondsSinceEpoch;
    final endTimestamp = endOfDay.millisecondsSinceEpoch;

    // 查询该日期范围内的所有文章
    return await db.query(
      tableName,
      where: '$columnCreateTime >= ? AND $columnCreateTime <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: '$columnCreateTime DESC', // 按创建时间倒序排列
    );
  }

  // ========== 扩展方法：更新文章（可选，用于编辑功能） ==========
  Future<int> updateRecord({
    required String firstName,
    required String lastName,
  }) async {
    final db = await database;
    final data = {
      columnFileName: lastName,
    };
    return await db.update(
      tableName,
      data,
      where: '$columnFileName = ?',
      whereArgs: [firstName],
    );
  }

  // ========== 工具方法：时间戳转DateTime（方便使用） ==========
  static DateTime timestampToDateTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ========== 扩展方法：删除文章（可选） ==========
  Future<int> deleteRecord(String name) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '$columnFileName = ?',
      whereArgs: [name],
    );
  }

  // 插入文件创建记录
  Future<int> insertRecord(String fileName, DateTime createTime) async {
    final db = await database;
    final data = {
      columnFileName: fileName,
      columnCreateTime: createTime.millisecondsSinceEpoch,
    };
    return await db.insert(tableName, data);
  }

  // 获取所有文件创建记录
  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final db = await database;
    return await db.query(tableName);
  }

  // 关闭数据库
  Future close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
