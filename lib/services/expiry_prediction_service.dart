import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ExpiryPredictionService {
  static Map<String, dynamic>? _expiryData;
  static Map<String, dynamic>? _categoryExpiryData;

  /// Load expiry data from `dataset.json` (only once).
  static Future<void> loadExpiryData() async {
    if (_expiryData == null) {
      try {
        final jsonString = await rootBundle.loadString("assets/dataset.json");
        _expiryData = jsonDecode(jsonString);
        print("✅ Expiry data loaded successfully.");
      } catch (e) {
        print("❌ Error loading expiry dataset: $e");
        _expiryData = {};
      }
    }
  }

  /// Load category fallback expiry from `categories.json` (only once).
  static Future<void> loadCategoryExpiry() async {
    if (_categoryExpiryData == null) {
      try {
        final jsonString =
            await rootBundle.loadString("assets/categories.json");
        _categoryExpiryData = jsonDecode(jsonString)["categories"];
        if (_categoryExpiryData == null || _categoryExpiryData!.isEmpty) {
          print("⚠️ categories.json is empty or incorrectly formatted.");
        } else {
          print("✅ Category expiry data loaded: $_categoryExpiryData");
        }
      } catch (e) {
        print("❌ Error loading category expiry dataset: $e");
        _categoryExpiryData = {};
      }
    }
  }

  /// Get expiry details for a product.
  /// 1. Look for an exact (or close) match in dataset.json.
  /// 2. If not found, fall back to the category data from categories.json.
  static Future<Map<String, String>> getExpiryDetails(
      String productName, String selectedCategory) async {
    await loadExpiryData();
    await loadCategoryExpiry();

    if (productName.trim().isEmpty) {
      print("❌ Product name is empty, cannot search.");
      return fallbackExpiry(selectedCategory);
    }

    String normalizedProductName = productName.toLowerCase().trim();
    Map<String, dynamic>? matchedItem;
    String matchedKey = "";

    // Step 1: Try to find an exact or close match within each category in dataset.json.
    for (var category in _expiryData!.values) {
      // Normalize keys for matching.
      final normalizedCategoryKeys = category
          .map((key, value) => MapEntry(key.toLowerCase().trim(), value));

      if (normalizedCategoryKeys.containsKey(normalizedProductName)) {
        matchedItem = normalizedCategoryKeys[normalizedProductName];
        matchedKey = normalizedProductName;
        break;
      }

      // Step 2: Check if any individual word matches.
      List<String> words = normalizedProductName.split(" ");
      for (var word in words) {
        if (normalizedCategoryKeys.containsKey(word)) {
          matchedItem = normalizedCategoryKeys[word];
          matchedKey = word;
          break;
        }
      }

      // Step 3: Try a substring match.
      if (matchedItem == null) {
        for (var key in normalizedCategoryKeys.keys) {
          if (normalizedProductName.contains(key) ||
              key.contains(normalizedProductName)) {
            matchedItem = normalizedCategoryKeys[key];
            matchedKey = key;
            break;
          }
        }
      }

      if (matchedItem != null) break;
    }

    // If found in dataset.json, return the expiry details.
    if (matchedItem != null) {
      print(
          "✅ Matched '$productName' with '$matchedKey' in dataset: $matchedItem");
      return {
        "pantry": "${matchedItem['pantry_max_days']} days",
        "fridge": "${matchedItem['fridge_max_days']} days",
        "freeze": "${matchedItem['freezer_max_days']} days"
      };
    }

    // If not found, fall back to category expiry details.
    print(
        "⚠️ Expiry data not found for '$productName'. Using category fallback for '$selectedCategory'.");
    return fallbackExpiry(selectedCategory);
  }

  /// Fallback function: returns expiry details based solely on the selected category.
  /// These values come from categories.json.
  static Map<String, String> fallbackExpiry(String category) {
    if (_categoryExpiryData == null || _categoryExpiryData!.isEmpty) {
      print("⚠️ Category expiry data not loaded. Using default fallback.");
      return {"pantry": "7 days", "fridge": "7 days", "freeze": "30 days"};
    }

    if (_categoryExpiryData!.containsKey(category)) {
      var categoryData = _categoryExpiryData![category];
      if (categoryData != null) {
        print("✅ Using category fallback for '$category': $categoryData");
        return {
          "pantry": "${categoryData["pantry"]} days",
          "fridge": "${categoryData["fridge"]} days",
          "freeze": "${categoryData["freeze"]} days"
        };
      }
    }

    print(
        "⚠️ Category '$category' not found in categories.json. Using default fallback.");
    return {"pantry": "7 days", "fridge": "7 days", "freeze": "30 days"};
  }

  /// Used for calculating actual expiry date (like "May 3, 2025") if user doesn't select one.
  static Future<Map<String, dynamic>> getBestExpiryForItem(
      String productName, String category) async {
    await loadExpiryData();
    await loadCategoryExpiry();

    final lowerName = productName.toLowerCase().trim();

    // Step 1: Try finding in dataset.json
    if (_expiryData![category] != null) {
      final items = _expiryData![category];
      for (var key in items.keys) {
        if (key.toLowerCase() == lowerName) {
          final pantry = items[key]['pantry_max_days'] ?? 0;
          final fridge = items[key]['fridge_max_days'] ?? 0;

          if (pantry > 0) {
            return {'days': pantry, 'storage': 'Pantry'};
          } else if (fridge > 0) {
            return {'days': fridge, 'storage': 'Fridge'};
          } else {
            return {'days': 0, 'storage': 'None'};
          }
        }
      }
    }

    // Step 2: fallback to categories.json
    final fallback = _categoryExpiryData![category] ?? {};
    final pantry = fallback['pantry'] ?? 0;
    final fridge = fallback['fridge'] ?? 0;

    if (pantry > 0) {
      return {'days': pantry, 'storage': 'Pantry'};
    } else if (fridge > 0) {
      return {'days': fridge, 'storage': 'Fridge'};
    } else {
      return {'days': 0, 'storage': 'None'};
    }
  }

  /// Normalize product name to improve matching.
  static String normalizeProductName(String productName) {
    List<String> stopWords = ["select", "premium", "organic", "fresh", "best"];
    return productName
        .toLowerCase()
        .split(' ')
        .where((word) => !stopWords.contains(word))
        .join(' ')
        .trim();
  }
}
