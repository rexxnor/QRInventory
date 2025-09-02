import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
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

  Item({required this.qrCode, required this.roomTag, required this.name, this.tags = const []});
}

class ItemProvider with ChangeNotifier {
  List<Item> _items = [];
  List<String> _rooms = [];
  List<String> _globalTags = [
    'Important',
    'To Do',
    'Archive',
    'Personal',
    'Work',
    'Urgent',
    'Miscellaneous',
  ];

  List<Item> get items => _items;
  List<String> get rooms => _rooms;
  List<String> get globalTags => _globalTags;

  void addItem(Item item) {
    _items.add(item);
    notifyListeners();
  }

  void addRoom(String room) {
    if (!_rooms.contains(room)) {
      _rooms.add(room);
      notifyListeners();
    }
  }

  List<Item> searchItems(String query) {
    return _items.where((item) => item.name.contains(query) || item.tags.contains(query) || item.roomTag.contains(query)).toList();
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
          child: ListView.builder(
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
                      child: Text(tag, style: TextStyle(color: Colors.white)),
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
class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose(); // Dispose of the controller to release resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Scanner'),
      ),
      body: MobileScanner(
          onDetect: (barcode) async {
            final String code = barcode.barcodes.first.rawValue!;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddItemFormScreen(qrCode: code),
            ));
          }
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Item Name'),
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode()); // Dismiss keyboard
              },
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
                  child: Text(tag, style: TextStyle(color: Colors.white)),
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
    );
  }

  Color _getTagColor(String tag) {
    return tagColors[tag.hashCode % tagColors.length];
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