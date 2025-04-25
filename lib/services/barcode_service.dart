import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeService {
  static Future<String?> fetchProductName(String barcode) async {
    final response = await http.get(Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 1) {
        return data['product']['product_name'] as String?;
      }
    }
    return null;
  }
}
