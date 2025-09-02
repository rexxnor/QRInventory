import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Inventory',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Inventory'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QRScanner()),
                );
              },
              child: Text('Scan QR Code'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ItemList()),
                );
              },
              child: Text('View Items'),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Scanner'),
      ),
      body: MobileScanner(
        onDetect: (barcode) async {
          String code = barcode.barcodes.first.rawValue!;
          // Navigate to the item details page to add more info
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetails(code: code),
            ),
          );
        },
      ),
    );
  }
}

class ItemList extends StatefulWidget {
  @override
  _ItemListState createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  List<Item> items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? itemList = prefs.getStringList('items');
    if (itemList != null) {
      setState(() {
        items = itemList.map((item) => Item.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> itemList = items.map((item) => item.toJson()).toList();
    await prefs.setStringList('items', itemList);
  }

  void _editItem(Item item) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController =
        TextEditingController(text: item.name);
        TextEditingController roomController =
        TextEditingController(text: item.room);
        String? selectedTag = item.tag;

        return AlertDialog(
          title: Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: roomController,
                decoration: InputDecoration(labelText: 'Room'),
              ),
              DropdownButton<String>(
                value: selectedTag,
                hint: Text('Select Tag'),
                items: ['Books', 'Plushies', 'Misc']
                    .map((tag) => DropdownMenuItem(
                  value: tag,
                  child: Text(tag),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTag = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  item.name = nameController.text;
                  item.room = roomController.text;
                  item.tag = selectedTag;
                });
                _saveItems();
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Items List'),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(items[index].name),
            subtitle: Text('Room: ${items[index].room}, Tag: ${items[index].tag}'),
            onTap: () => _editItem(items[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add new item screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ItemDetails()),
          ).then((value) {
            if (value != null) {
              setState(() {
                items.add(value);
                _saveItems();
              });
            }
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class ItemDetails extends StatefulWidget {
  final String? code;

  ItemDetails({this.code});

  @override
  _ItemDetailsState createState() => _ItemDetailsState();
}

class _ItemDetailsState extends State<ItemDetails> {
  TextEditingController codeController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController roomController = TextEditingController();
  String? selectedTag;

  @override
  void initState() {
    super.initState();
    if (widget.code != null) {
      codeController.text = widget.code!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(labelText: 'QR Code'),
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: roomController,
              decoration: InputDecoration(labelText: 'Room'),
            ),
            DropdownButton<String>(
              value: selectedTag,
              hint: Text('Select Tag'),
              items: ['Books', 'Plushies', 'Misc']
                  .map((tag) => DropdownMenuItem(
                value: tag,
                child: Text(tag),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedTag = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, Item(
                  box: codeController.text,
                  name: nameController.text,
                  room: roomController.text,
                  tag: selectedTag,
                ));
              },
              child: Text('Save Item'),
            ),
          ],
        ),
      ),
    );
  }
}
class Item {
  String box;
  String name;
  String room;
  String? tag;

  Item({required this.box, required this.name, required this.room, this.tag});

  String toJson() {
    return '{"name": "$name", "room": "$room", "tag": "$tag"}';
  }

  static Item fromJson(String json) {
    final Map<String, dynamic> data = jsonDecode(json);
    return Item(
      box: data['box'],
      name: data['name'],
      room: data['room'],
      tag: data['tag'],
    );
  }
}