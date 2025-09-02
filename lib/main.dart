import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}


class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> resetDatabase() async {
    // Get the directory for the app's documents
    String path = join(await getDatabasesPath(), 'items.db');

    // Delete the database
    try {
      await deleteDatabase(path);
      print("Database deleted successfully.");
    } catch (e) {
      print("Error deleting database: $e");
    }
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'items.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          qrCode TEXT UNIQUE NOT NULL,
          roomTag TEXT,
          name TEXT NOT NULL,
          tags TEXT
        )
        ''');
      },
    );
  }

  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Item>> getItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('items');

    return List.generate(maps.length, (i) {
      return Item.fromMap(maps[i]);
    });
  }

  Future<void> deleteItem(String qrCode) async {
    final db = await database;
    await db.delete('items', where: 'qrCode = ?', whereArgs: [qrCode]);
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update('items', item.toMap(), where: 'qrCode = ?', whereArgs: [item.qrCode]);
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ItemProvider(),
      child: MaterialApp(
        title: 'Box Tracker',
        theme: ThemeData.light().copyWith(
          primaryColor: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HomeScreen(),
      ),
    );
  }
}


class Item {
  String qrCode;
  String roomTag;
  String name;
  List<String> tags;

  Item({
    required this.qrCode,
    required this.roomTag,
    required this.name,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'qrCode': qrCode,
      'roomTag': roomTag,
      'name': name,
      'tags': json.encode(tags), // Store tags as a JSON string
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      qrCode: map['qrCode'],
      roomTag: map['roomTag'],
      name: map['name'],
      tags: List<String>.from(json.decode(map['tags'])), // Decode JSON string back to List
    );
  }
}


class ItemProvider with ChangeNotifier {
  List<Item> _items = [];
  List<String> _rooms = [];
  List<String> _globalTags = [
    'Books',
    'Documents',
    'Archive',
    'Toys',
    'Misc.',
  ];

  bool _isLoading = true;

  List<Item> get items => _items;
  List<String> get rooms => _rooms;
  List<String> get globalTags => _globalTags;
  bool get isLoading => _isLoading;

  ItemProvider() {
    _loadItems(); // Load items from SQLite on initialization
    _loadRooms(); // Load rooms from SQLite on initialization
  }

  Future<void> _loadItems() async {
    _items = await DatabaseHelper().getItems(); // Fetch items from the database
    _isLoading = false; // Update loading state
    notifyListeners(); // Notify listeners about the change
  }

  Future<void> addItem(Item item) async {
    await DatabaseHelper().insertItem(item); // Insert item into the database
    _items.add(item); // Add item to the local list
    notifyListeners(); // Notify listeners about the change
  }

  Future<void> addRoom(String room) async {
    if (!_rooms.contains(room)) {
      _rooms.add(room); // Add room to the local list
      notifyListeners(); // Notify listeners about the change
      // You may want to implement a method to save rooms to the database if needed
    }
  }

  Future<void> _loadRooms() async {
    // If you want to manage rooms in SQLite, implement a method in DatabaseHelper
    // For now, this can be left empty or you can load from a different table
    notifyListeners(); // Notify listeners about the change
  }

  List<Item> searchItems(String query) {
    return _items.where((item) =>
    item.name.contains(query) ||
        item.tags.contains(query) ||
        item.roomTag.contains(query)
    ).toList();
  }
}


class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Box Tracker')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: ItemList()),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => QRCodeScannerScreen()));
              },
              child: Text('Add Item via QR Code'),
            ),
            ResetDataButton()
          ],
        ),
      ),
    );
  }
}

class ItemList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);
    TextEditingController searchController = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(labelText: 'Search Items'),
            onChanged: (value) {
              itemProvider.searchItems(value);
            },
          ),
        ),
        Expanded(
          child: itemProvider.isLoading
              ? Center(child: CircularProgressIndicator()) // Show loading indicator
              : ListView.builder(
            itemCount: itemProvider.items.length,
            itemBuilder: (context, index) {
              final item = itemProvider.items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('Room: ${item.roomTag}'),
                trailing: Wrap(
                  spacing: 6, // space between tags
                  children: item.tags.map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTagColor(tag),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tag, style: TextStyle(color: _getTextColor(_getTagColor(tag)))),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getTagColor(String tag) {
    final colors = [
      Color(0xFF4CAF50), // Green
      Color(0xFF2196F3), // Blue
      Color(0xFFFF9800), // Orange
      Color(0xFFF44336), // Red
      Color(0xFF9C27B0), // Purple
      Color(0xFF3F51B5), // Indigo
      Color(0xFF009688), // Teal
      Color(0xFF795548), // Brown
      Color(0xFF607D8B), // Blue Grey
      Color(0xFFFFEB3B), // Yellow
      Color(0xFFCDDC39), // Lime
      Color(0xFF00BCD4), // Cyan
      Color(0xFF673AB7), // Deep Purple
      Color(0xFF3E2723), // Dark Brown
    ];
    return colors[tag.hashCode % colors.length];
  }

  Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine text color
    return (backgroundColor.computeLuminance() > 0.5) ? Colors.black : Colors.white;
  }
}

class QRCodeScannerScreen extends StatefulWidget {
  @override
  _QRCodeScannerScreenState createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(autoStart: false);
  StreamSubscription<Object?>? _subscription;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Start listening to lifecycle changes.
    WidgetsBinding.instance.addObserver(this);

    // Start listening to the barcode events.
    _subscription = controller.barcodes.listen(_handleBarcode);

    // Finally, start the scanner itself.
    unawaited(controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the controller is not ready, do not try to start or stop it.
    if (!controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      // Stop the scanner when the app is paused.
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
        break;
      case AppLifecycleState.resumed:
      // Restart the scanner when the app is resumed.
        _subscription = controller.barcodes.listen(_handleBarcode);
        unawaited(controller.start());
        break;
      case AppLifecycleState.inactive:
      // Stop the scanner when the app is inactive.
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
        break;
    }
  }

  void _handleBarcode(BarcodeCapture barcode) async {
    if (isProcessing) return; // Prevent multiple scans
    isProcessing = true;

    final String code = barcode.barcodes.first.rawValue!;

    Navigator.of(this.context).push(MaterialPageRoute(
      builder: (context) => AddItemFormScreen(qrCode: code),
    )).then((_) {
      // Restart the scanner when returning from AddItemFormScreen
      unawaited(controller.start());
      isProcessing = false; // Reset the flag after navigation
    });
  }

  @override
  Future<void> dispose() async {
    // Stop listening to lifecycle changes.
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening to the barcode events.
    await _subscription?.cancel();
    _subscription = null;
    // Dispose the controller.
    await controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Scanner'),
      ),
      body: SafeArea(
        child: MobileScanner(
          controller: controller,
          onDetect: (barcode) {
            _handleBarcode(barcode);
          },
        ),
      ),
    );
  }
}

class AddItemFormScreen extends StatefulWidget {
  final String qrCode;

  AddItemFormScreen({required this.qrCode});

  @override
  _AddItemFormScreenState createState() => _AddItemFormScreenState();
}

class _AddItemFormScreenState extends State<AddItemFormScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  String? selectedRoom;
  List<String> tags = [];

  // Predefined list of colors for tags
  final List<Color> tagColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFCDDC39), // Lime
    Color(0xFF00BCD4), // Cyan
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3E2723), // Dark Brown
  ];

  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);

    return Scaffold(
        appBar: AppBar(
          title: Text('Add New Item'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(
          child:
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Item Name'),
                  //onTap: () {
                  //  FocusScope.of(context).requestFocus(FocusNode()); // Dismiss keyboard
                  //},
                ),
                DropdownButton<String>(
                  value: selectedRoom,
                  hint: Text('Select Room'),
                  items: itemProvider.rooms.map((room) {
                    return DropdownMenuItem<String>(
                      value: room,
                      child: Text(room),
                    );
                  }).toList()
                    ..add(DropdownMenuItem<String>(
                      value: 'Add New Room',
                      child: Text('Add New Room'),
                    )),
                  onChanged: (value) {
                    if (value == 'Add New Room') {
                      _showAddRoomDialog(context);
                    } else {
                      setState(() {
                        selectedRoom = value;
                      });
                    }
                  },
                ),
                DropdownButton<String>(
                  hint: Text('Select Tags'),
                  items: itemProvider.globalTags.map((tag) {
                    return DropdownMenuItem<String>(
                      value: tag,
                      child: Text(tag),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        tags.add(value);
                        tagsController.text = tags.join(', '); // Update the text field
                      });
                    }
                  },
                ),
                Wrap(
                  children: tags.map((tag) {
                    return Container(
                      margin: EdgeInsets.all(4.0),
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: _getTagColor(tag),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(tag, style: TextStyle(color: _getTextColor(_getTagColor(tag)))),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isEmpty || selectedRoom == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill in all fields.')),
                      );
                      return;
                    }

                    final item = Item(
                      qrCode: widget.qrCode,
                      roomTag: selectedRoom ?? '',
                      name: nameController.text,
                      tags: tags,
                    );
                    itemProvider.addItem(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Item added successfully!')),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text('Add Item'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Go back to the main view
                  },
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),



        )

    );
  }

  Color _getTagColor(String tag) {
    return tagColors[tag.hashCode % tagColors.length];
  }

  Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine text color
    return (backgroundColor.computeLuminance() > 0.5) ? Colors.black : Colors.white;
  }

  void _showAddRoomDialog(BuildContext context) {
    final TextEditingController roomController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Room'),
          content: TextField(
            controller: roomController,
            decoration: InputDecoration(labelText: 'Room Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final roomName = roomController.text;
                if (roomName.isNotEmpty) {
                  Provider.of<ItemProvider>(context, listen: false).addRoom(roomName);
                  setState(() {
                    selectedRoom = roomName; // Auto-select the newly added room
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class ResetDataButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Show a confirmation dialog before deleting
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm Reset"),
              content: Text("Are you sure you want to reset all data?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("Reset"),
                ),
              ],
            );
          },
        );

        if (confirm == true) {
          await DatabaseHelper._instance.resetDatabase();
          // Optionally, navigate to a different screen or show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Data has been reset.")),
          );
          SystemNavigator.pop();
        }
      },
      child: Text("Reset All Data"),
    );
  }
}