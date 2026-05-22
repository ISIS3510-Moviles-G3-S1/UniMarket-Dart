import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OrderHistoryDatabase {
  static final OrderHistoryDatabase _instance = OrderHistoryDatabase._internal();
  factory OrderHistoryDatabase() => _instance;
  OrderHistoryDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'order_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders(
            id TEXT PRIMARY KEY,
            date TEXT,
            subtotal REAL,
            buyer TEXT,
            pickupLocation TEXT,
            paymentDetails TEXT,
            productSnapshot TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert('orders', order, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;
    return await db.query('orders', orderBy: 'date DESC');
  }
}
