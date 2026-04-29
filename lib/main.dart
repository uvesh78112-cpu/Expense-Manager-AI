import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

void main() => runApp(const ExpenseManagerApp());

class ExpenseManagerApp extends StatefulWidget {
  const ExpenseManagerApp({super.key});

  @override
  State<ExpenseManagerApp> createState() => _ExpenseManagerAppState();
}

class _ExpenseManagerAppState extends State<ExpenseManagerApp> {
  Color accentColor = Colors.cyanAccent;
  double cardRadius = 24.0;

  void updateTheme(Color newColor, double newRadius) {
    setState(() {
      accentColor = newColor;
      cardRadius = newRadius;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: accentColor,
      ),
      home: ExpenseManagerHome(
        onThemeChange: updateTheme,
        currentAccent: accentColor,
        radius: cardRadius,
      ),
    );
  }
}

class ExpenseManagerHome extends StatefulWidget {
  final Function(Color, double) onThemeChange;
  final Color currentAccent;
  final double radius;

  const ExpenseManagerHome({
    super.key,
    required this.onThemeChange,
    required this.currentAccent,
    required this.radius,
  });

  @override
  State<ExpenseManagerHome> createState() => _ExpenseManagerHomeState();
}

class _ExpenseManagerHomeState extends State<ExpenseManagerHome> {
  final List<Map<String, dynamic>> expenses = [];
  final ImagePicker _picker = ImagePicker();

  double get totalSpending {
    double sum = 0;
    for (var item in expenses) {
      String cleanAmt = item['amount'].replaceAll(RegExp(r'[^0-9.]'), '');
      sum += double.tryParse(cleanAmt) ?? 0;
    }
    return sum;
  }

  Future<void> processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    ); // Supports English/European
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    String fullText = recognizedText.text;
    String detectedMedicalNo = "Not Available";
    String paymentType = "Detected: Other";
    String detectedCurrency = "₹"; // Default
    double maxAmount = 0.0;

    // 1. Universal Amount & Currency Detection
    if (fullText.contains('\$'))
      detectedCurrency = "\$";
    else if (fullText.contains('€'))
      detectedCurrency = "€";
    else if (fullText.contains('£'))
      detectedCurrency = "£";

    RegExp amountEx = RegExp(r'\d+[.,]\d{2}');
    for (var m in amountEx.allMatches(fullText)) {
      double val = double.tryParse(m.group(0)!.replaceAll(',', '.')) ?? 0;
      if (val > maxAmount) maxAmount = val;
    }

    // 2. Medical & Bill ID Extraction (Keywords search)
    RegExp idEx = RegExp(
      r'(GST|Reg|Lic|Bill|Inv|ID)[:\s]+([A-Z0-9-]+)',
      caseSensitive: false,
    );
    var idMatch = idEx.firstMatch(fullText);
    if (idMatch != null) detectedMedicalNo = idMatch.group(2) ?? "Found";

    // 3. Smart Payment Detection
    String lowText = fullText.toLowerCase();
    if (lowText.contains("upi") ||
        lowText.contains("gpay") ||
        lowText.contains("phonepe") ||
        lowText.contains("paytm"))
      paymentType = "UPI / Digital";
    else if (lowText.contains("cash"))
      paymentType = "Cash Payment";
    else if (lowText.contains("card") ||
        lowText.contains("visa") ||
        lowText.contains("mastercard"))
      paymentType = "Card Payment";

    // 4. Auto-Categorization
    String category = "General";
    if (lowText.contains('med') ||
        lowText.contains('hosp') ||
        lowText.contains('clinic') ||
        lowText.contains('pharma'))
      category = "Medical";
    else if (lowText.contains('fuel') ||
        lowText.contains('petrol') ||
        lowText.contains('diesel'))
      category = "Fuel";
    else if (lowText.contains('rest') ||
        lowText.contains('cafe') ||
        lowText.contains('food'))
      category = "Dining";

    setState(() {
      expenses.insert(0, {
        "title": recognizedText.blocks.isNotEmpty
            ? recognizedText.blocks.first.text
            : "New Receipt",
        "amount": "$detectedCurrency${maxAmount.toStringAsFixed(2)}",
        "category": category,
        "idInfo": detectedMedicalNo,
        "payMethod": paymentType,
        "imagePath": image.path,
        "fullText": fullText,
        "date": DateTime.now().toString().split(' ')[0],
      });
    });
    textRecognizer.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "EXPENSE MANAGER AI",
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.palette, color: widget.currentAccent),
            onPressed: _showThemeSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeroCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  "RECENT SCANS",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Opacity(
                      opacity: 0.2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.document_scanner,
                            size: 80,
                            color: widget.currentAccent,
                          ),
                          const SizedBox(height: 10),
                          const Text("No bills scanned yet"),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: expenses.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2128),
                        borderRadius: BorderRadius.circular(widget.radius),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => DetailScreen(
                              data: expenses[i],
                              color: widget.currentAccent,
                            ),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: widget.currentAccent.withOpacity(
                            0.1,
                          ),
                          child: Icon(
                            _getIcon(expenses[i]['category']),
                            color: widget.currentAccent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          expenses[i]['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "${expenses[i]['date']} • ${expenses[i]['payMethod']}",
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          expenses[i]['amount'],
                          style: TextStyle(
                            color: widget.currentAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "gal",
            onPressed: () => processImage(ImageSource.gallery),
            backgroundColor: const Color(0xFF1C2128),
            child: Icon(Icons.collections, color: widget.currentAccent),
          ),
          const SizedBox(width: 15),
          FloatingActionButton.extended(
            heroTag: "cam",
            onPressed: () => processImage(ImageSource.camera),
            backgroundColor: widget.currentAccent,
            label: const Text(
              "SCAN RECEIPT",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.camera_alt, color: Colors.black),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String cat) {
    if (cat == "Medical") return Icons.medical_information;
    if (cat == "Fuel") return Icons.local_gas_station;
    if (cat == "Dining") return Icons.restaurant;
    return Icons.receipt_long;
  }

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          colors: [widget.currentAccent, widget.currentAccent.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: [
          BoxShadow(
            color: widget.currentAccent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TOTAL ANALYZED",
            style: TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "₹${totalSpending.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "UI CUSTOMIZATION",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _cOp(Colors.cyanAccent),
                  _cOp(Colors.lightGreenAccent),
                  _cOp(Colors.amberAccent),
                  _cOp(Colors.deepOrangeAccent),
                  _cOp(Colors.white),
                ],
              ),
              const SizedBox(height: 30),
              Slider(
                value: widget.radius,
                min: 0,
                max: 40,
                activeColor: widget.currentAccent,
                onChanged: (v) {
                  widget.onThemeChange(widget.currentAccent, v);
                  setSS(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cOp(Color c) => GestureDetector(
    onTap: () => widget.onThemeChange(c, widget.radius),
    child: CircleAvatar(
      backgroundColor: c,
      radius: 20,
      child: widget.currentAccent == c
          ? const Icon(Icons.check, color: Colors.black, size: 15)
          : null,
    ),
  );
}

class DetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  const DetailScreen({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text("AI RECEIPT ANALYSIS"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Hero(
              tag: data['imagePath'],
              child: Container(
                margin: const EdgeInsets.all(15),
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: FileImage(File(data['imagePath'])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _row("Final Amount", data['amount']),
                  _row("Category", data['category']),
                  _row("Reference / ID", data['idInfo']),
                  _row("Payment Method", data['payMethod']),
                  _row("Scan Date", data['date']),
                  const Divider(height: 50, color: Colors.white10),
                  const Text(
                    "RAW TEXT DETECTED",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      data['fullText'],
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.grey)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
