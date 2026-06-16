import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('products');
  runApp(const CatalogApp());
}

class CatalogApp extends StatelessWidget {
  const CatalogApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 80, color: Colors.indigo),
            SizedBox(height: 20),
            Text("View Your Products", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
            SizedBox(height: 10),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box box = Hive.box('products');
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Products"), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box b, _) {
                final keys = b.keys.where((k) => b.get(k)['name'].toString().toLowerCase().contains(searchQuery)).toList();
                if (keys.isEmpty) return const Center(child: Text("No products found"));
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: keys.length,
                  itemBuilder: (ctx, i) {
                    final k = keys[i];
                    final p = b.get(k);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: p['img'] != null ? Image.file(File(p['img']), fit: BoxFit.cover, width: double.infinity) : Container(color: Colors.grey[300], child: const Icon(Icons.image))),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                                Text("Sell: \$${p['sell']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _form(key: k, p: p)),
                                    IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => b.delete(k)),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _form(), child: const Icon(Icons.add)),
    );
  }

  void _form({dynamic key, Map? p}) {
    final nC = TextEditingController(text: p?['name'] ?? '');
    final bC = TextEditingController(text: p?['buy'] ?? '');
    final sC = TextEditingController(text: p?['sell'] ?? '');
    String? img = p?['img'];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(key == null ? "Add Product" : "Edit Product", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final pic = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (pic != null) {
                    final dir = await getApplicationDocumentsDirectory();
                    final saved = await File(pic.path).copy('${dir.path}/${path.basename(pic.path)}');
                    setS(() => img = saved.path);
                  }
                },
                child: Container(
                  height: 120, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                  child: img == null ? const Icon(Icons.add_a_photo) : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(img!), fit: BoxFit.cover)),
                ),
              ),
              TextField(controller: nC, decoration: const InputDecoration(labelText: "Product Name")),
              TextField(controller: bC, decoration: const InputDecoration(labelText: "Buy Price"), keyboardType: TextInputType.number),
              TextField(controller: sC, decoration: const InputDecoration(labelText: "Sell Price"), keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  if (nC.text.isEmpty) return;
                  final data = {'name': nC.text, 'buy': bC.text, 'sell': sC.text, 'img': img};
                  key == null ? box.add(data) : box.put(key, data);
                  Navigator.pop(context);
                },
                child: const Text("Save Product"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      )),
    );
  }
}
