import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';

part 'commerce_widgets.dart';
part 'operations_widgets.dart';
part 'messaging_widgets.dart';
part 'transaction_widgets.dart';

const ink = Color(0xff22251f),
    green = Color(0xff264d3d),
    cream = Color(0xfff7f7f2);
const womenCategories = [
  'Outfit',
  'Topwear',
  'Bottomwear',
  'Footwear',
  'Dresses',
  'Shoes',
  'Bags',
  'Accessories',
];
const menCategories = ['Suit', 'Shoes'];
const categories = ['All', ...womenCategories, 'Suit'];
const specialCollections = ['New Arrivals', 'Best Sellers', 'Sale / Clearance'];
String money(num n) =>
    'MWK ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
void main() => runApp(const MarysFashionApp());

class MarysFashionApp extends StatelessWidget {
  final bool inventory;
  const MarysFashionApp({super.key, this.inventory = false});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: inventory ? 'Mary Inventory' : 'Mary’s Fashion | marysfashion',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'BrandSans',
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: cream,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, color: ink),
        headlineLarge: TextStyle(
          fontFamily: 'BrandSerif',
          fontSize: 44,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'BrandSerif',
          fontSize: 30,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffd5dbd2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    home: Home(inventory: inventory),
  );
}

class Api {
  static String token = '';
  static String refreshToken = '';
  static String userEmail = '';
  static String userId = '';
  static http.Client client = http.Client();
  static String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static String supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const previewMode = bool.fromEnvironment('PREVIEW_MODE');
  static bool get usesSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  static String get base {
    const b = String.fromEnvironment('API_URL');
    return b.isNotEmpty
        ? b
        : (Uri.base.scheme.startsWith('http')
              ? Uri.base.origin
              : defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:8083'
              : 'http://127.0.0.1:8083');
  }

  static Future<Map<String, dynamic>> call(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (!usesSupabase && path == 'products') await _loadSupabaseConfig();
    if (usesSupabase &&
        ![
          'products',
          'orders',
          'track',
          'admin',
          'upload',
          'product',
          'shop-settings',
          'status',
          'supplier',
          'stock-event',
          'return',
          'collection',
          'payment',
          'messages',
          'message-thread',
          'message-send',
          'message-read',
          'message-status',
        ].contains(path)) {
      throw Exception(
        'Staff Supabase connection is not set up yet. Use the shared API_URL for both apps until migration is complete.',
      );
    }
    if (usesSupabase &&
        [
          'products',
          'orders',
          'track',
          'admin',
          'upload',
          'product',
          'shop-settings',
          'status',
          'supplier',
          'stock-event',
          'return',
          'collection',
          'payment',
          'messages',
          'message-thread',
          'message-send',
          'message-read',
          'message-status',
        ].contains(path)) {
      return _supabaseCall(path, data);
    }
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final r =
        await (data == null
                ? client.get(Uri.parse('$base/api/$path'), headers: headers)
                : client.post(
                    Uri.parse('$base/api/$path'),
                    headers: headers,
                    body: jsonEncode(data),
                  ))
            .timeout(const Duration(seconds: 15));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Something went wrong');
    }
    return body;
  }

  static Future<void> signIn(String email, String password) async {
    await _loadSupabaseConfig();
    if (!usesSupabase) {
      final r = await call('login', {'password': password});
      token = r['token'] as String;
      return;
    }
    final response = await client
        .post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {'Content-Type': 'application/json', 'apikey': supabaseKey},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        body['msg'] ?? body['error_description'] ?? 'Unable to sign in',
      );
    }
    token = body['access_token'] as String? ?? '';
    refreshToken = body['refresh_token'] as String? ?? '';
    userId = (body['user'] as Map?)?['id']?.toString() ?? '';
    userEmail = email.trim();
    if (token.isEmpty)
      throw Exception('Supabase did not return a session token');
  }

  static Future<void> signUp(String email, String password) async {
    await _loadSupabaseConfig();
    if (!usesSupabase)
      throw Exception('Accounts require the Supabase website connection.');
    final response = await client
        .post(
          Uri.parse('$supabaseUrl/auth/v1/signup'),
          headers: {'Content-Type': 'application/json', 'apikey': supabaseKey},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400)
      throw Exception(
        body['msg'] ?? body['error_description'] ?? 'Unable to create account',
      );
    final access = body['access_token'] as String?;
    if (access != null && access.isNotEmpty) {
      token = access;
      refreshToken = body['refresh_token'] as String? ?? '';
      userId = (body['user'] as Map?)?['id']?.toString() ?? '';
    }
    userEmail = email.trim();
  }

  static Future<void> signOut() async {
    token = '';
    refreshToken = '';
    userEmail = '';
    userId = '';
  }

  static Future<bool> signInWithGoogle() async {
    await _loadSupabaseConfig();
    if (!usesSupabase) throw Exception('Google sign-in requires Supabase.');
    final redirect = Uri.base.scheme.startsWith('http')
        ? Uri.base.origin
        : base;
    final uri = Uri.parse(
      '$supabaseUrl/auth/v1/authorize',
    ).replace(queryParameters: {'provider': 'google', 'redirect_to': redirect});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void restoreOAuthSession() {
    final fragment = Uri.base.fragment;
    if (fragment.isEmpty) return;
    final values = Uri.splitQueryString(fragment);
    final access = values['access_token'];
    if (access != null && access.isNotEmpty) {
      token = access;
      refreshToken = values['refresh_token'] ?? '';
      try {
        final payload = jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(access.split('.')[1])),
          ),
        );
        userId = payload['sub']?.toString() ?? '';
      } catch (_) {}
      userEmail = 'Google account';
    }
  }

  static Future<void> _loadSupabaseConfig() async {
    if (usesSupabase) return;
    final response = await client
        .get(Uri.parse('$base/api/auth-config'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 400) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    supabaseUrl = body['url'] as String? ?? '';
    supabaseKey = body['publishable_key'] as String? ?? '';
  }

  static Future<Map<String, dynamic>> _supabaseCall(
    String path,
    Map<String, dynamic>? data,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'apikey': supabaseKey,
      'Authorization': 'Bearer ${token.isNotEmpty ? token : supabaseKey}',
    };
    late http.Response response;
    if (path == 'admin') {
      final responses = await Future.wait([
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/products?select=id,name,category,regular_price,sale_price,unit_cost,description,images,variants,collections,active&order=created_at.asc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/shop_settings?select=enabled_categories,enabled_collections&limit=1',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/orders?select=id,customer,phone,address,delivery,delivery_fee,total,status,payment_status,payment_reference,created_at,updated_at&order=created_at.desc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/order_items?select=id,order_id,product_id,product_name,variant,quantity,unit_price,regular_price,unit_cost&order=id.asc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/stock_events?select=id,kind,product_id,variant,quantity,delta,supplier_id,reference,reason,created_at&order=created_at.desc&limit=200',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/returns?select=id,order_id,order_item_id,quantity,suitable_for_resale,amount,reason,refund_status,created_at&order=created_at.desc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/payment_collections?select=id,order_id,amount,reference,created_at&order=created_at.desc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/suppliers?select=id,name,contact,notes,created_at&order=name.asc',
          ),
          headers: headers,
        ),
        client.get(
          Uri.parse(
            '$supabaseUrl/rest/v1/payment_transactions?select=tx_ref,order_id,amount,currency,status,provider_reference,payment_method,channel,provider_type,provider_mode,provider_charges,completed_at,created_at,updated_at&order=created_at.desc',
          ),
          headers: headers,
        ),
      ]).timeout(const Duration(seconds: 15));
      if (responses.any((item) => item.statusCode >= 400)) {
        throw Exception('Unable to load inventory from Supabase.');
      }
      final rows = jsonDecode(responses.first.body) as List;
      final settingsRows = jsonDecode(responses[1].body) as List;
      final orderRows = jsonDecode(responses[2].body) as List;
      final itemRows = jsonDecode(responses[3].body) as List;
      final movementRows = jsonDecode(responses[4].body) as List;
      final returnRows = jsonDecode(responses[5].body) as List;
      final collectionRows = jsonDecode(responses[6].body) as List;
      final supplierRows = jsonDecode(responses[7].body) as List;
      final transactionRows = jsonDecode(responses[8].body) as List;
      final orders = orderRows.map((row) {
        final order = Map<String, dynamic>.from(row as Map);
        order['payment'] = order['payment_status'];
        order['items'] = itemRows
            .where((item) => (item as Map)['order_id'] == order['id'])
            .map((item) {
              final line = Map<String, dynamic>.from(item as Map);
              line['database_id'] = line['id'];
              line['id'] = line.remove('product_id');
              line['qty'] = line.remove('quantity');
              line['price'] = line.remove('unit_price');
              line['cost'] = line.remove('unit_cost');
              line['name'] = line.remove('product_name');
              return line;
            })
            .toList();
        return order;
      }).toList();
      final reportData = _supabaseReports(
        rows,
        orders,
        returnRows,
        collectionRows,
      );
      final itemById = {
        for (final raw in itemRows)
          (raw as Map)['id']: Map<String, dynamic>.from(raw),
      };
      final orderById = {for (final order in orders) order['id']: order};
      return {
        'products': rows.map((row) {
          final p = Map<String, dynamic>.from(row as Map);
          final regular = p.remove('regular_price') as int;
          p['cost'] = p.remove('unit_cost') ?? 0;
          p['regular_price'] = regular;
          p['price'] = p['sale_price'] ?? regular;
          p['collections'] = (p['collections'] as List?)?.cast<String>() ?? [];
          p['image'] = (p['images'] as List).first;
          return p;
        }).toList(),
        'settings': settingsRows.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(settingsRows.first as Map),
        'suppliers': supplierRows,
        'returns': returnRows.map((row) {
          final value = Map<String, dynamic>.from(row as Map);
          final item = itemById[value['order_item_id']];
          value['product'] = item?['product_id'];
          value['variant'] = item?['variant'];
          value['qty'] = value.remove('quantity');
          value['restock'] = value.remove('suitable_for_resale') == true
              ? 1
              : 0;
          return value;
        }).toList(),
        'collections': collectionRows,
        'transactions': [
          ...transactionRows.map((row) {
            final transaction = Map<String, dynamic>.from(row as Map);
            final order = orderById[transaction['order_id']];
            transaction['customer'] = order?['customer'] ?? 'Customer';
            transaction['order_status'] = order?['status'];
            transaction['source'] = 'PayChangu';
            return transaction;
          }),
          ...collectionRows
              .where((collection) {
                final value = collection as Map;
                return !transactionRows.any(
                  (transaction) =>
                      (transaction as Map)['order_id'] == value['order_id'] &&
                      (transaction)['status'] == 'success',
                );
              })
              .map((row) {
                final collection = Map<String, dynamic>.from(row as Map);
                final order = orderById[collection['order_id']];
                return {
                  'tx_ref': 'MANUAL-${collection['reference']}',
                  'order_id': collection['order_id'],
                  'amount': collection['amount'],
                  'currency': 'MWK',
                  'status': 'success',
                  'provider_reference': collection['reference'],
                  'payment_method': 'Manual collection',
                  'channel': 'Staff recorded',
                  'provider_type': 'Manual payment',
                  'provider_mode': 'offline',
                  'provider_charges': 0,
                  'completed_at': collection['created_at'],
                  'created_at': collection['created_at'],
                  'updated_at': collection['created_at'],
                  'customer': order?['customer'] ?? 'Customer',
                  'order_status': order?['status'],
                  'source': 'Manual collection',
                };
              }),
        ],
        'orders': orders,
        'movements': movementRows.map((row) {
          final event = Map<String, dynamic>.from(row as Map);
          event['product'] = event.remove('product_id');
          event['created'] = event.remove('created_at');
          return event;
        }).toList(),
        ...reportData,
      };
    }
    if (path == 'shop-settings') {
      response = await client
          .patch(
            Uri.parse('$supabaseUrl/rest/v1/shop_settings?id=eq.true'),
            headers: {...headers, 'Prefer': 'return=minimal'},
            body: jsonEncode({
              'enabled_categories': data!['enabled_categories'],
              'enabled_collections': data['enabled_collections'],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        throw Exception('Unable to save shop visibility settings.');
      }
      return {'ok': true};
    }
    if (path == 'messages') {
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/rpc/messaging_threads'),
            headers: headers,
            body: jsonEncode({'p_staff': data?['staff'] == true}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400)
        throw Exception('Unable to load messages.');
      return {'threads': jsonDecode(response.body) as List};
    }
    if (path == 'message-thread') {
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/rpc/messaging_messages'),
            headers: headers,
            body: jsonEncode({'p_thread_id': data?['thread_id']}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400)
        throw Exception('Unable to load this conversation.');
      return {'messages': jsonDecode(response.body) as List};
    }
    if (path == 'message-send') {
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/rpc/messaging_send'),
            headers: headers,
            body: jsonEncode({
              'p_thread_id': data?['thread_id'],
              'p_body': data?['body'],
              'p_subject': data?['subject'],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400)
        throw Exception('Unable to send message.');
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    if (path == 'message-read' || path == 'message-status') {
      final rpc = path == 'message-read'
          ? 'messaging_mark_read'
          : 'messaging_set_status';
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/rpc/$rpc'),
            headers: headers,
            body: jsonEncode(
              path == 'message-read'
                  ? {'p_thread_id': data?['thread_id']}
                  : {
                      'p_thread_id': data?['thread_id'],
                      'p_status': data?['status'],
                    },
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400)
        throw Exception('Unable to update conversation.');
      return response.body.isEmpty
          ? {'ok': true}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    if (path == 'payment') {
      response = await client
          .post(
            Uri.parse('$supabaseUrl/functions/v1/paychangu'),
            headers: headers,
            body: jsonEncode(data ?? {}),
          )
          .timeout(const Duration(seconds: 20));
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        throw Exception(
          body is Map
              ? body['error'] ?? 'Unable to process payment.'
              : 'Unable to process payment.',
        );
      }
      return Map<String, dynamic>.from(body as Map);
    }
    if ([
      'status',
      'supplier',
      'stock-event',
      'return',
      'collection',
    ].contains(path)) {
      final payload = Map<String, dynamic>.from(data ?? {});
      if (path == 'return') {
        final order = payload['order_id'];
        final product = payload['product'];
        final variant = payload['variant'];
        final orderResponse = await client
            .get(
              Uri.parse(
                '$supabaseUrl/rest/v1/order_items?select=id&order_id=eq.$order&product_id=eq.$product&variant=eq.${Uri.encodeQueryComponent(variant.toString())}&limit=1',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15));
        if (orderResponse.statusCode >= 400)
          throw Exception('Unable to find the returned order item.');
        final items = jsonDecode(orderResponse.body) as List;
        if (items.isEmpty)
          throw Exception('Unable to find the returned order item.');
        payload['order_item_id'] = (items.first as Map)['id'];
      }
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/rpc/staff_operation'),
            headers: headers,
            body: jsonEncode({'p_action': path, 'p_data': payload}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        throw Exception(
          body is Map
              ? (body['message'] ??
                    body['hint'] ??
                    'Unable to complete the staff operation.')
              : 'Unable to complete the staff operation.',
        );
      }
      return response.body.isEmpty
          ? {'ok': true}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    if (path == 'upload') {
      final filename = data?['filename'] as String? ?? 'image.jpg';
      final productId = data?['product_id'] as String?;
      final raw = base64Decode(data?['data'] as String? ?? '');
      if (productId == null || productId.isEmpty) {
        throw Exception('Missing product image folder.');
      }
      final extension = filename.split('.').last.toLowerCase();
      final storedName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
      final objectPath = '${Uri.encodeComponent(productId)}/$storedName';
      response = await client
          .post(
            Uri.parse(
              '$supabaseUrl/storage/v1/object/product-images/$objectPath',
            ),
            headers: {
              ...headers,
              'Content-Type': extension == 'png'
                  ? 'image/png'
                  : extension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg',
              'x-upsert': 'false',
            },
            body: raw,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        String detail = response.body;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            detail =
                body['message']?.toString() ??
                body['error']?.toString() ??
                body['statusCode']?.toString() ??
                detail;
          }
        } catch (_) {}
        throw Exception(
          'Upload failed (${response.statusCode}): ${detail.trim()}',
        );
      }
      return {
        'image':
            '$supabaseUrl/storage/v1/object/public/product-images/$objectPath',
      };
    }
    if (path == 'product') {
      if (data?['delete'] == true) {
        final id = data!['id']?.toString();
        if (id == null || id.isEmpty) {
          throw Exception('Missing product id.');
        }
        response = await client
            .patch(
              Uri.parse('$supabaseUrl/rest/v1/products?id=eq.$id'),
              headers: {...headers, 'Prefer': 'return=representation'},
              body: jsonEncode({'active': false}),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode >= 400) {
          throw Exception('Unable to delete this product from the website.');
        }
        return {'ok': true, 'deleted': true};
      }
      final product = {
        'id': data!['id'],
        'name': data['name'],
        'category': data['category'],
        'regular_price': data['price'],
        'sale_price': data['sale_price'],
        'unit_cost': data['cost'],
        'description': data['description'],
        'images': data['images'],
        'variants': data['variants'],
        'collections': data['collections'] ?? [],
        'active': data['active'] == true,
      };
      response = await client
          .post(
            Uri.parse('$supabaseUrl/rest/v1/products'),
            headers: {
              ...headers,
              'Prefer': 'resolution=merge-duplicates,return=representation',
            },
            body: jsonEncode(product),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        throw Exception('Unable to publish this product to Supabase.');
      }
      return {'ok': true};
    }
    if (path == 'products') {
      final productsFuture = client.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/products?select=id,name,category,regular_price,sale_price,description,images,variants,collections,active&active=eq.true&order=created_at.asc',
        ),
        headers: headers,
      );
      final settingsFuture = client.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/shop_settings?select=standard_delivery_mwk,express_delivery_mwk,delivery_areas,pickup_location,contact,returns_policy,enabled_categories,enabled_collections&limit=1',
        ),
        headers: headers,
      );
      final responses = await Future.wait([productsFuture, settingsFuture])
          .timeout(const Duration(seconds: 15));
      if (responses.any((r) => r.statusCode >= 400)) {
        throw Exception('The shop catalogue is temporarily unavailable.');
      }
      final rows = jsonDecode(responses.first.body) as List;
      final settingsRows = jsonDecode(responses.last.body) as List;
      return {
        'products': rows.map((row) {
          final p = Map<String, dynamic>.from(row as Map);
          final images = (p['images'] as List?)?.cast<String>() ?? <String>[];
          final regular = p['regular_price'] as int;
          p['image'] = images.isEmpty ? 'dress.jpg' : images.first;
          p['price'] = p['sale_price'] ?? regular;
          return p;
        }).toList(),
        'settings': settingsRows.isEmpty
            ? <String, dynamic>{}
            : {
                ...Map<String, dynamic>.from(settingsRows.first as Map),
                'delivery_fees': {
                  'Pickup': 0,
                  'Delivery': settingsRows.first['standard_delivery_mwk'],
                  'Express': settingsRows.first['express_delivery_mwk'],
                },
              },
      };
    }
    if (path == 'orders' && previewMode) {
      return {
        'id': 'PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
        'total': data!['expected_total'],
        'items': data['items'],
        'preview': true,
        'message': 'Preview order only — no stock or payment was changed.',
      };
    }
    final rpc = path == 'orders' ? 'place_order' : 'track_order';
    final payload = path == 'orders'
        ? {
            'p_key': data!['key'],
            'p_customer': data['customer'],
            'p_phone': data['phone'],
            'p_address': data['address'],
            'p_delivery': data['delivery'],
            'p_items': data['items'],
            'p_expected_total': data['expected_total'],
          }
        : {'p_id': data!['id'], 'p_token': data['token']};
    response = await client
        .post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/$rpc'),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = decoded is Map
          ? decoded['message'] ?? decoded['error']
          : null;
      throw Exception(message ?? 'Unable to complete the request.');
    }
    final result = Map<String, dynamic>.from(decoded as Map);
    if (path == 'orders') {
      result['items'] = data['items'];
    }
    return result;
  }

  static DateTime? _reportDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toUtc();

  static DateTime _reportMonth(DateTime value) =>
      DateTime.utc(value.year, value.month);

  static DateTime _reportAddMonths(DateTime value, int amount) {
    final month = value.month - 1 + amount;
    return DateTime.utc(value.year + month ~/ 12, month % 12 + 1);
  }

  static Map<String, dynamic> _supabaseReports(
    List products,
    List orders,
    List returns,
    List collections,
  ) {
    final completed = orders
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((order) => order['status'] == 'Completed')
        .map((order) {
          order['_reportDate'] =
              _reportDate(order['updated_at']) ??
              _reportDate(order['created_at']);
          return order;
        })
        .where((order) => order['_reportDate'] != null)
        .toList();
    final currentCosts = <String, int>{
      for (final value in products)
        (value as Map)['id'] as String: (value['unit_cost'] ?? 0) as int,
    };

    Map<String, dynamic> totals(List periodOrders, List periodReturns) {
      var sales = 0;
      var cost = 0;
      var units = 0;
      var estimated = 0;
      final byProduct = <String, Map<String, dynamic>>{};
      for (final order in periodOrders) {
        for (final rawLine in order['items'] as List) {
          final line = Map<String, dynamic>.from(rawLine as Map);
          final quantity = line['qty'] as int;
          final price = line['price'] as int;
          final lineCost = line['cost'] as int?;
          sales += quantity * price;
          units += quantity;
          if (lineCost == null) estimated++;
          cost += quantity * (lineCost ?? currentCosts[line['id']] ?? 0);
          final product = byProduct.putIfAbsent(
            line['id'] as String,
            () => {
              'id': line['id'],
              'name': line['name'],
              'units': 0,
              'sales': 0,
            },
          );
          product['units'] = (product['units'] as int) + quantity;
          product['sales'] = (product['sales'] as int) + quantity * price;
        }
      }
      var returnValue = 0;
      for (final rawReturn in periodReturns) {
        final item = Map<String, dynamic>.from(rawReturn as Map);
        returnValue += item['amount'] as int;
        if (item['suitable_for_resale'] == true) {
          final order = periodOrders.cast<Map>().firstWhere(
            (value) => value['id'] == item['order_id'],
            orElse: () => <String, dynamic>{},
          );
          final line = (order['items'] as List? ?? []).cast<Map>().firstWhere(
            (value) => value['database_id'] == item['order_item_id'],
            orElse: () => <String, dynamic>{},
          );
          if (line.isNotEmpty) {
            cost -=
                (item['quantity'] as int) *
                (line['cost'] as int? ?? currentCosts[line['id']] ?? 0);
          }
        }
      }
      final net = sales - returnValue;
      return {
        'completed_orders': periodOrders.length,
        'item_sales': sales,
        'returns_value': returnValue,
        'net_item_sales': net,
        'cost_of_goods': cost,
        'gross_margin': net - cost,
        'units_sold': units,
        'average_order_value': periodOrders.isEmpty
            ? 0
            : (net / periodOrders.length).round(),
        'estimated_cost_lines': estimated,
        'top_products':
            (byProduct.values.toList()..sort((a, b) {
                  final salesOrder = (b['sales'] as int).compareTo(
                    a['sales'] as int,
                  );
                  return salesOrder == 0
                      ? (b['units'] as int).compareTo(a['units'] as int)
                      : salesOrder;
                }))
                .take(5)
                .toList(),
      };
    }

    Map<String, dynamic> report(
      DateTime start,
      DateTime end,
      DateTime previousStart,
      String bucketKind,
    ) {
      final selected = completed.where((order) {
        final date = order['_reportDate'] as DateTime;
        return !date.isBefore(start) && date.isBefore(end);
      }).toList();
      final previous = completed.where((order) {
        final date = order['_reportDate'] as DateTime;
        return !date.isBefore(previousStart) && date.isBefore(start);
      }).toList();
      List inPeriod(List values, DateTime from, DateTime until) =>
          values.where((value) {
            final date = _reportDate((value as Map)['created_at']);
            return date != null && !date.isBefore(from) && date.isBefore(until);
          }).toList();
      final current = totals(selected, inPeriod(returns, start, end));
      final prior = totals(previous, inPeriod(returns, previousStart, start));
      final previousSales = prior['net_item_sales'] as int;
      final currentSales = current['net_item_sales'] as int;
      current['comparison_percent'] = previousSales == 0
          ? null
          : (currentSales - previousSales) * 100 / previousSales;
      current['previous_net_item_sales'] = previousSales;
      current['margin_rate'] = currentSales == 0
          ? 0
          : (current['gross_margin'] as int) * 100 / currentSales;
      final buckets = <Map<String, dynamic>>[];
      var cursor = start;
      while (cursor.isBefore(end)) {
        final bucketEnd = bucketKind == 'day'
            ? cursor.add(const Duration(days: 1))
            : _reportAddMonths(cursor, 1);
        final bucketOrders = selected.where((order) {
          final date = order['_reportDate'] as DateTime;
          return !date.isBefore(cursor) && date.isBefore(bucketEnd);
        }).toList();
        final bucket = totals(
          bucketOrders,
          inPeriod(returns, cursor, bucketEnd),
        );
        buckets.add({
          'label': bucketKind == 'day'
              ? '${cursor.month.toString().padLeft(2, '0')}/${cursor.day.toString().padLeft(2, '0')}'
              : _monthName(cursor.month),
          'sales': bucket['net_item_sales'],
          'margin': bucket['gross_margin'],
          'orders': bucketOrders.length,
        });
        cursor = bucketEnd;
      }
      current['buckets'] = buckets;
      current['start'] = start.toIso8601String().substring(0, 10);
      current['end'] = end
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      return current;
    }

    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final month = _reportMonth(now);
    final nextMonth = _reportAddMonths(month, 1);
    final sevenStart = today.subtract(const Duration(days: 6));
    final sixStart = _reportAddMonths(month, -5);
    final yearStart = _reportAddMonths(month, -11);
    final allStart = completed.isEmpty
        ? month
        : completed
              .map((order) => order['_reportDate'] as DateTime)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final monthReport = report(
      month,
      nextMonth,
      _reportAddMonths(month, -1),
      'day',
    );
    final dailyReport = report(
      today,
      today.add(const Duration(days: 1)),
      today.subtract(const Duration(days: 1)),
      'day',
    );
    final sevenDayReport = report(
      sevenStart,
      today.add(const Duration(days: 1)),
      sevenStart.subtract(const Duration(days: 7)),
      'day',
    );
    final sixReport = report(
      sixStart,
      nextMonth,
      _reportAddMonths(sixStart, -6),
      'month',
    );
    final yearReport = report(
      yearStart,
      nextMonth,
      _reportAddMonths(yearStart, -12),
      'month',
    );
    final allReport = report(allStart, nextMonth, allStart, 'month');
    final statuses = <String, int>{};
    for (final order in orders) {
      final status = order['status'].toString();
      statuses[status] = (statuses[status] ?? 0) + 1;
    }
    int stockValue(String priceKey) => products.fold(0, (sum, value) {
      final product = value as Map;
      final variants = (product['variants'] as Map).values.cast<int>();
      final price = (product[priceKey] ?? 0) as int;
      return sum +
          variants.fold(0, (subtotal, quantity) => subtotal + quantity * price);
    });
    return {
      'report': allReport,
      'reports': {
        'daily': dailyReport,
        'seven_days': sevenDayReport,
        'month': monthReport,
        'six_months': sixReport,
        'year': yearReport,
      },
      'business_health': {
        'stock_cost_value': stockValue('unit_cost'),
        'stock_retail_value': products.fold(0, (sum, value) {
          final product = value as Map;
          final variants = (product['variants'] as Map).values.cast<int>();
          final price =
              (product['sale_price'] ?? product['regular_price']) as int;
          return sum +
              variants.fold(
                0,
                (subtotal, quantity) => subtotal + quantity * price,
              );
        }),
        'low_stock_variants': products.fold<int>(
          0,
          (sum, value) =>
              sum +
              ((value as Map)['variants'] as Map).values
                  .cast<int>()
                  .where((quantity) => quantity <= 3)
                  .length,
        ),
        'active_products': products
            .where((value) => (value as Map)['active'] == true)
            .length,
        'order_statuses': statuses,
        'cash_recorded': collections.fold(
          0,
          (sum, value) => sum + ((value as Map)['amount'] as int),
        ),
        'refunds_pending': returns
            .where((value) => (value as Map)['refund_status'] != 'Refunded')
            .fold(0, (sum, value) => sum + ((value as Map)['amount'] as int)),
      },
    };
  }

  static String _monthName(int month) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month];
}

class Home extends StatefulWidget {
  final bool inventory;
  const Home({super.key, required this.inventory});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Timer? refreshTimer;
  Timer? heroPrimaryTimer;
  Timer? heroSecondaryTimer;
  int heroPrimaryIndex = 0;
  int heroSecondaryIndex = 1;
  int heroTick = 0;
  bool fetching = false;
  final staffEmail = TextEditingController();
  final staffPassword = TextEditingController();

  @override
  void dispose() {
    refreshTimer?.cancel();
    heroPrimaryTimer?.cancel();
    heroSecondaryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    staffEmail.dispose();
    staffPassword.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      startRefresh();
      startHeroRotation();
    } else {
      refreshTimer?.cancel();
      heroPrimaryTimer?.cancel();
      heroSecondaryTimer?.cancel();
    }
  }

  void startRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!busy && (!widget.inventory || Api.token.isNotEmpty)) load();
    });
  }

  void startHeroRotation() {
    heroPrimaryTimer?.cancel();
    heroSecondaryTimer?.cancel();
    if (widget.inventory) return;
    heroPrimaryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || products.isEmpty || busy) return;
      setState(() {
        heroTick++;
        heroPrimaryIndex = (heroPrimaryIndex + 1) % products.length;
      });
    });
    heroSecondaryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || products.isEmpty || busy) return;
      setState(() {
        heroTick++;
        heroSecondaryIndex = (heroSecondaryIndex + 1) % products.length;
      });
    });
  }

  List<dynamic> products = [], orders = [], movements = [];
  List<dynamic> messageThreads = [];
  final List<Map<String, dynamic>> bag = [];
  final Set<String> saved = {};
  final Set<String> compared = {};
  String audience = 'Woman',
      category = 'All',
      collection = 'All',
      query = '',
      sort = 'Featured',
      page = 'Shop',
      error = '';
  bool loading = true, onlySaved = false, busy = false;
  Map<String, dynamic>? confirmation;
  String checkoutKey = '';
  Map<String, dynamic> staffData = {}, settings = {};
  bool memoryReady = false;
  Future<void> memoryWrites = Future.value();
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (memoryReady && !widget.inventory) {
      final value = jsonEncode({
        'items': bag,
        'saved': saved.toList(),
        'checkout_key': checkoutKey,
      });
      memoryWrites = memoryWrites
          .then((_) => ShopMemory.write(value))
          .catchError((Object _) {});
    }
  }

  Future<void> restore() async {
    if (!widget.inventory) {
      try {
        final raw = await ShopMemory.read();
        if (raw != null) {
          final data = jsonDecode(raw) as Map;
          final items = (data['items'] as List)
              .map((v) => Map<String, dynamic>.from(v))
              .where(
                (v) =>
                    v['id'] is String &&
                    v['variant'] is String &&
                    v['qty'] is int &&
                    v['qty'] > 0 &&
                    v['price'] is int &&
                    v['name'] is String &&
                    v['image'] is String,
              )
              .toList();
          bag.addAll(items);
          saved.addAll((data['saved'] as List).cast<String>());
          checkoutKey = data['checkout_key'] as String? ?? '';
        }
      } catch (_) {
        bag.clear();
        saved.clear();
      }
    }
    memoryReady = true;
    if (mounted) await load();
  }

  @override
  void initState() {
    super.initState();
    Api.restoreOAuthSession();
    page = widget.inventory ? 'Inventory' : 'Shop';
    WidgetsBinding.instance.addObserver(this);
    startRefresh();
    restore();
  }

  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    final requestToken = Api.token;
    try {
      final r = await Api.call(
        widget.inventory && Api.token.isNotEmpty ? 'admin' : 'products',
      );
      if (!mounted || requestToken != Api.token) return;
      List<dynamic> loadedMessageThreads = messageThreads;
      if (widget.inventory && Api.usesSupabase && Api.token.isNotEmpty) {
        try {
          final messages = await Api.call('messages', {'staff': true});
          loadedMessageThreads = messages['threads'] ?? [];
        } catch (_) {
          loadedMessageThreads = [];
        }
      }
      setState(() {
        products = r['products'];
        staffData = r;
        settings = Map<String, dynamic>.from(r['settings'] ?? {});
        for (final line in bag) {
          final matching = products.where((p) => p['id'] == line['id']);
          if (matching.isNotEmpty) {
            line['price'] = matching.first['price'];
            line['regular_price'] =
                matching.first['regular_price'] ?? matching.first['price'];
          }
        }
        orders = r['orders'] ?? [];
        movements = r['movements'] ?? [];
        messageThreads = loadedMessageThreads;
        loading = false;
        error = '';
      });
      startHeroRotation();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    } finally {
      fetching = false;
    }
  }

  void tell(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> action(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      tell(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int stock(dynamic p) =>
      (p['variants'] as Map).values.fold<int>(0, (a, b) => a + (b as int));
  int get count => bag.fold(0, (a, b) => a + (b['qty'] as int));
  int get subtotal =>
      bag.fold(0, (a, b) => a + (b['qty'] as int) * (b['price'] as int));
  Widget photo(dynamic p, {BoxFit fit = BoxFit.cover}) =>
      productImage(p, fit: fit);
  Widget title(String t, [String? s]) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: Theme.of(context).textTheme.headlineMedium),
        if (s != null) ...[
          const SizedBox(height: 8),
          Text(s, style: const TextStyle(color: Color(0xff647064))),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 800;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 86,
        backgroundColor: cream,
        titleSpacing: wide ? 36 : 18,
        title: Row(
          children: [
            Image.asset(
              'assets/images/nyasa-threads-logo.png',
              package: 'mary_shared',
              width: wide ? 56 : 48,
              height: wide ? 56 : 48,
              semanticLabel: 'Mary’s Fashion thread logo',
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.inventory ? 'Mary Inventory' : 'Mary’s',
                    style: TextStyle(
                      fontFamily: 'BrandSerif',
                      fontSize: wide ? 36 : 27,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.inventory ? 'STOCK & PRODUCTS' : 'FASHION',
                    style: TextStyle(
                      fontSize: wide ? 12 : 10,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.inventory && wide)
              const Flexible(
                child: Text(
                  '  / inventory',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        actions: widget.inventory
            ? [
                if (Api.token.isNotEmpty)
                  IconButton(
                    tooltip: 'Shop settings',
                    onPressed: shopSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                if (Api.token.isNotEmpty && Api.usesSupabase)
                  Badge(
                    label: Text(
                      '${messageThreads.where((thread) => (thread as Map)['unread'] == true).length}',
                    ),
                    isLabelVisible: messageThreads.any(
                      (thread) => (thread as Map)['unread'] == true,
                    ),
                    child: IconButton(
                      tooltip: 'Messages',
                      onPressed: () => setState(() => page = 'Messages'),
                      icon: const Icon(Icons.mark_chat_unread_outlined),
                    ),
                  ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                ),
                if (Api.token.isNotEmpty)
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () {
                      Api.token = '';
                      setState(() {
                        orders = [];
                        movements = [];
                        messageThreads = [];
                      });
                      load();
                    },
                    icon: const Icon(Icons.logout),
                  ),
                const SizedBox(width: 16),
              ]
            : [
                if (wide)
                  TextButton(
                    onPressed: () => setState(() {
                      page = 'Shop';
                      audience = 'Woman';
                      category = 'All';
                    }),
                    child: const Text('Explore Woman'),
                  ),
                if (wide)
                  TextButton(
                    onPressed: () => setState(() {
                      page = 'Shop';
                      audience = 'Men';
                      category = 'All';
                    }),
                    child: const Text('Men'),
                  ),
                Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: IconButton(
                    tooltip: 'Shopping cart',
                    onPressed: () => setState(() => page = 'Cart'),
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
                if (Api.usesSupabase)
                  IconButton(
                    tooltip: Api.token.isEmpty
                        ? 'Sign in to messages'
                        : 'Messages',
                    onPressed: () async {
                      if (Api.token.isEmpty) {
                        final signedIn = await showDialog<bool>(
                          context: context,
                          builder: (_) => const AccountDialog(),
                        );
                        if (signedIn == true && mounted) setState(() {});
                      } else {
                        setState(() => page = 'Messages');
                      }
                    },
                    icon: Icon(
                      Api.token.isEmpty
                          ? Icons.account_circle_outlined
                          : Icons.mark_chat_unread_outlined,
                    ),
                  ),
                IconButton(
                  tooltip: 'Favourites',
                  onPressed: () => setState(() {
                    page = 'Shop';
                    onlySaved = !onlySaved;
                  }),
                  icon: Icon(
                    onlySaved ? Icons.favorite : Icons.favorite_border,
                    color: onlySaved ? Colors.red : ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    tooltip: 'Track an order',
                    onPressed: track,
                    icon: const Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: load, child: const Text('Try again')),
                ],
              ),
            )
          : widget.inventory
          ? inventory()
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 48 : 18,
                      vertical: 12,
                    ),
                    child: page == 'Shop'
                        ? shop(wide)
                        : page == 'Messages'
                        ? SizedBox(height: 620, child: CustomerMessagesPage())
                        : cart(),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: widget.inventory && Api.token.isNotEmpty
          ? NavigationBar(
              selectedIndex: [
                'Inventory',
                'Orders',
                'Activity',
                'Operations',
                'Reports',
                if (Api.usesSupabase) 'Messages',
                if (Api.usesSupabase) 'Transactions',
              ].indexOf(page),
              onDestinationSelected: (i) => setState(
                () => page = [
                  'Inventory',
                  'Orders',
                  'Activity',
                  'Operations',
                  'Reports',
                  if (Api.usesSupabase) 'Messages',
                  if (Api.usesSupabase) 'Transactions',
                ][i],
              ),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: 'Inventory',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Activity',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  label: 'Operations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                if (Api.usesSupabase)
                  const NavigationDestination(
                    icon: Icon(Icons.mark_chat_unread_outlined),
                    label: 'Messages',
                  ),
                if (Api.usesSupabase)
                  const NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    label: 'Transactions',
                  ),
              ],
            )
          : null,
    );
  }

  void shopSettings() {
    final enabledCategories = {
      ...((settings['enabled_categories'] as List?)?.cast<String>() ??
          categories.skip(1)),
    };
    final enabledCollections = {
      ...((settings['enabled_collections'] as List?)?.cast<String>() ??
          specialCollections),
    };
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Shop settings'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Show or hide sections on the customer website. Products are not deleted.',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Categories',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final item in categories.skip(1))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      value: enabledCategories.contains(item),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          enabledCategories.add(item);
                        } else {
                          enabledCategories.remove(item);
                        }
                      }),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Special collections',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final item in specialCollections)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      value: enabledCollections.contains(item),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          enabledCollections.add(item);
                        } else {
                          enabledCollections.remove(item);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.call('shop-settings', {
                    'enabled_categories': enabledCategories.toList(),
                    'enabled_collections': enabledCollections.toList(),
                  });
                  if (!mounted) return;
                  setState(() {
                    settings['enabled_categories'] = enabledCategories.toList();
                    settings['enabled_collections'] = enabledCollections
                        .toList();
                  });
                  Navigator.pop(dialogContext);
                } catch (e) {
                  tell(e);
                }
              },
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }

  void help() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shopping with Mary’s'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Size & fit', style: TextStyle(fontSize: 22)),
                const Text(
                  'Check the size and colour listed on each product. Sizes differ between styles: ask the shop for garment or shoe measurements before ordering if unsure. Product descriptions include available material and fit details.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Delivery & collection',
                  style: TextStyle(fontSize: 22),
                ),
                Text(
                  settings['delivery_areas']?.toString().isNotEmpty == true
                      ? settings['delivery_areas']
                      : 'Delivery areas are awaiting confirmation by the shop.',
                ),
                Text(
                  settings['pickup_location']?.toString().isNotEmpty == true
                      ? 'Pickup: ${settings['pickup_location']}'
                      : 'Contact the shop to confirm the pickup location.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Returns & exchanges',
                  style: TextStyle(fontSize: 22),
                ),
                Text(
                  settings['returns_policy']?.toString().isNotEmpty == true
                      ? settings['returns_policy']
                      : 'Please confirm return and exchange terms with the shop before purchasing. A final policy has not been published yet.',
                ),
                const SizedBox(height: 18),
                const Text('Contact', style: TextStyle(fontSize: 22)),
                Text(
                  settings['contact']?.toString().isNotEmpty == true
                      ? settings['contact']
                      : 'Shop contact details will appear here once configured.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget shop(bool wide) {
    final enabledCategories =
        (settings['enabled_categories'] as List?)?.cast<String>() ??
        categories.skip(1).toList();
    final enabledCollections =
        (settings['enabled_collections'] as List?)?.cast<String>() ??
        specialCollections;
    final activeCategories = audience == 'Men'
        ? menCategories
        : womenCategories;
    final q = query.trim().toLowerCase();
    var list = products
        .where(
          (p) =>
              activeCategories.contains(p['category']) &&
              (category == 'All' ||
                  (enabledCategories.contains(category) &&
                      p['category'] == category)) &&
              (collection == 'All' ||
                  (enabledCollections.contains(collection) &&
                      ((p['collections'] as List?)?.contains(collection) ??
                          false))) &&
              (q.isEmpty ||
                  [
                    p['name'],
                    p['category'],
                    p['description'],
                    p['id'],
                    p['price'],
                    p['regular_price'] ?? p['price'],
                    (p['collections'] as List?)?.join(' '),
                    (p['variants'] as Map?)?.keys.join(' '),
                  ].join(' ').toString().toLowerCase().contains(q)) &&
              (!onlySaved || saved.contains(p['id'])),
        )
        .toList();
    if (sort == 'Price: low to high') {
      list.sort((a, b) => (a['price'] as int).compareTo(b['price']));
    }
    if (sort == 'Price: high to low') {
      list.sort((a, b) => (b['price'] as int).compareTo(a['price']));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: help,
            icon: const Icon(Icons.help_outline),
            label: const Text('Size, delivery & returns'),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: green,
          child: const Text(
            'MARY’S FASHION  ·  Dresses, shoes & finishing touches  ·  MWK',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THE MARY’S EDIT',
                    style: TextStyle(
                      letterSpacing: 3,
                      color: green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A little elegance.\nEvery day.',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontSize: wide ? 60 : 40, height: 1.02),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Find the dress. Add the shoes. Make it yours.\nExplore your next everyday favourites.',
                    style: TextStyle(height: 1.7, color: Color(0xff5a645c)),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => setState(() => category = 'Dresses'),
                    label: const Text('Explore dresses'),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
            ),
            if (wide && products.isNotEmpty) ...[
              const SizedBox(width: 32),
              SizedBox(
                width: 440,
                height: 285,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _heroTile(
                        product: products[heroPrimaryIndex % products.length],
                        imageIndex: 0,
                        large: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _heroTile(
                              product: _heroSecondaryProduct(),
                              imageIndex: _heroSecondaryImageIndex(),
                              large: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            color: green,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 10,
                            ),
                            child: const Text(
                              'THE FINISHING\nTOUCH',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 1.7,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Explore Woman'),
              selected: audience == 'Woman',
              onSelected: (_) => setState(() {
                audience = 'Woman';
                category = 'All';
              }),
            ),
            ChoiceChip(
              label: const Text('Men'),
              selected: audience == 'Men',
              onSelected: (_) => setState(() {
                audience = 'Men';
                category = 'All';
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', ...activeCategories]
              .where(
                (c) =>
                    c == 'All' ||
                    enabledCategories.contains(c) ||
                    audience == 'Men',
              )
              .map(
                (c) => ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(c),
                  ),
                  selected: category == c,
                  onSelected: (_) => setState(() => category = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 4, top: 10),
              child: Text(
                'Special collections',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final c in ['All', ...enabledCollections])
              ChoiceChip(
                label: Text(c),
                selected: collection == c,
                onSelected: (_) => setState(() => collection = c),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: wide ? 360 : double.infinity,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Find your next favourite',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            SizedBox(
              width: wide ? null : double.infinity,
              child: DropdownButton<String>(
                isExpanded: !wide,
                value: sort,
                items: ['Featured', 'Price: low to high', 'Price: high to low']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => sort = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (compared.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: compared.length < 2 ? null : compareProducts,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text('Compare ${compared.length} pieces'),
                ),
                TextButton(
                  onPressed: () => setState(() => compared.clear()),
                  child: const Text('Clear comparison'),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                onlySaved
                    ? 'Your saved pieces'
                    : '${category == 'All' ? 'The collection' : category}  /  ${list.length} pieces',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (onlySaved)
              TextButton(
                onPressed: () => setState(() => onlySaved = false),
                child: const Text('Show all'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(50),
            child: Text('No pieces found. Try another search or category.'),
          ),
        LayoutBuilder(
          builder: (c, b) {
            final columns = b.maxWidth > 1000
                ? 4
                : b.maxWidth > 650
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: wide ? 24 : 12,
                mainAxisSpacing: 24,
                childAspectRatio: wide ? 0.59 : 0.49,
              ),
              itemBuilder: (c, i) {
                final p = list[i];
                return InkWell(
                  onTap: () => detail(p),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: photo(p),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  tooltip: 'Save ${p['name']}',
                                  onPressed: () => setState(
                                    () => saved.contains(p['id'])
                                        ? saved.remove(p['id'])
                                        : saved.add(p['id']),
                                  ),
                                  icon: Icon(
                                    saved.contains(p['id'])
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: saved.contains(p['id'])
                                        ? Colors.red
                                        : green,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 58,
                              top: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  tooltip: 'Add ${p['name']} to cart',
                                  onPressed: stock(p) == 0
                                      ? null
                                      : () => detail(p),
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 20,
                                    color: green,
                                  ),
                                ),
                              ),
                            ),
                            if (stock(p) <= 3)
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    stock(p) == 0
                                        ? 'Sold out'
                                        : 'Only a few left',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p['category'].toString().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          color: Color(0xff697469),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        p['name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 5),
                      priceLabel(p, size: 14),
                      const Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Color(0xffd59a28)),
                          SizedBox(width: 3),
                          Text(
                            '4.8',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Verified reviews',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xff697469),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => setState(() {
                          if (compared.contains(p['id'])) {
                            compared.remove(p['id']);
                          } else if (compared.length < 3) {
                            compared.add(p['id']);
                          } else {
                            tell('Compare up to three pieces at a time.');
                          }
                        }),
                        icon: Icon(
                          compared.contains(p['id'])
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        label: const Text(
                          'Compare',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(wide ? 32 : 22),
          decoration: const BoxDecoration(
            color: Color(0xffedf0ea),
            border: Border(top: BorderSide(color: Color(0xffd5dbd2))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 60,
                runSpacing: 22,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Mary’s Fashion',
                    style: TextStyle(
                      fontFamily: 'BrandSerif',
                      fontSize: 34,
                      color: ink,
                    ),
                  ),
                  const Text(
                    'Wear what feels like you.',
                    style: TextStyle(fontSize: 16, color: green),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xffcbd3c7)),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 30,
                runSpacing: 10,
                children: [
                  Text(
                    'marysfashion',
                    style: TextStyle(fontSize: 13, letterSpacing: 1.2),
                  ),
                  Text(
                    'Dresses  /  Shoes  /  Bags  /  Accessories',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Prices in Malawi kwacha',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Preview collection · Products and delivery rates are illustrative.',
                style: TextStyle(fontSize: 12, color: Color(0xff697469)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void detail(dynamic p) {
    showDialog(
      context: context,
      builder: (dialogContext) => EnhancedProductDetails(
        product: Map<String, dynamic>.from(p as Map),
        saved: saved.contains(p['id']),
        onSave: () => setState(
          () => saved.contains(p['id'])
              ? saved.remove(p['id'])
              : saved.add(p['id']),
        ),
        onCompare: () {
          if (!compared.contains(p['id']) && compared.length >= 3) {
            tell('Compare up to three pieces at a time.');
            return;
          }
          setState(() => compared.add(p['id']));
          Navigator.pop(dialogContext);
        },
        onAdd: (selectedVariant, quantity, image) {
          final existing = bag.where(
            (b) => b['id'] == p['id'] && b['variant'] == selectedVariant,
          );
          final old = existing.isEmpty ? 0 : existing.first['qty'] as int;
          if (old + quantity > p['variants'][selectedVariant]) {
            tell('That quantity is already in your cart.');
            return;
          }
          setState(() {
            if (existing.isEmpty) {
              bag.add({
                'id': p['id'],
                'name': p['name'],
                'price': p['price'],
                'regular_price': p['regular_price'] ?? p['price'],
                'variant': selectedVariant,
                'qty': quantity,
                'image': image,
                'category': p['category'],
              });
            } else {
              existing.first['qty'] += quantity;
            }
            checkoutKey = '';
          });
          Navigator.pop(dialogContext);
          tell('Added to your cart');
        },
      ),
    );
  }

  Widget cartLine(Map<String, dynamic> item, {required bool compact}) {
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease quantity',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            if (item['qty'] > 1) {
              item['qty']--;
            } else {
              bag.remove(item);
            }
            checkoutKey = '';
          }),
          icon: const Icon(Icons.remove),
        ),
        Text(
          '${item['qty']}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            final product = products.firstWhere(
              (p) => p['id'] == item['id'],
              orElse: () => <String, dynamic>{'variants': <String, dynamic>{}},
            );
            if (item['qty'] < (product['variants'][item['variant']] ?? 0)) {
              item['qty']++;
            }
            checkoutKey = '';
          }),
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Remove item',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            bag.remove(item);
            checkoutKey = '';
          }),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item['name'], maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(
          item['variant'],
          style: const TextStyle(fontSize: 12, color: Color(0xff697469)),
        ),
        const SizedBox(height: 6),
        priceLabel(item, size: 14),
      ],
    );
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: compact
            ? Row(
                children: [
                  SizedBox(width: 76, height: 88, child: photo(item)),
                  const SizedBox(width: 12),
                  Expanded(child: information),
                  const SizedBox(width: 4),
                  controls,
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 65, height: 85, child: photo(item)),
                  SizedBox(width: 180, child: information),
                  controls,
                ],
              ),
      ),
    );
  }

  Widget cart() {
    if (confirmation != null) {
      return OrderConfirmation(
        order: confirmation!,
        onContinue: () => setState(() {
          confirmation = null;
          page = 'Shop';
        }),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => page = 'Shop'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('The collection'),
        ),
        title('Your shopping cart', '$count pieces, chosen by you.'),
        if (bag.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text('Your cart is waiting for something beautiful.'),
          ),
        for (final b in bag)
          cartLine(b, compact: MediaQuery.sizeOf(context).width < 560),
        if (bag.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Subtotal  ${money(subtotal)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Pickup is free. Standard delivery: ${money(settings['delivery_fees']?['Delivery'] ?? 3000)}.\nYou will review the full total before placing your order.',
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: checkout,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Continue to checkout'),
          ),
        ],
      ],
    );
  }

  Future<void> checkout() async {
    final previousTotal = subtotal;
    await load();
    if (!mounted || bag.isEmpty || error.isNotEmpty) return;
    if (previousTotal != subtotal) {
      tell(
        'A price changed. Review the updated cart, then continue to checkout.',
      );
      return;
    }
    for (final line in bag) {
      final p = products.where((p) => p['id'] == line['id']).firstOrNull;
      if (p == null || (p['variants'][line['variant']] ?? 0) < line['qty']) {
        tell(
          '${line['name']}: this size or quantity is unavailable. Update your cart to continue.',
        );
        return;
      }
    }
    checkoutKey = checkoutKey.isEmpty
        ? List.generate(
            24,
            (_) => Random.secure().nextInt(16).toRadixString(16),
          ).join()
        : checkoutKey;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => CheckoutFlow(
        lines: bag.map((b) => Map<String, dynamic>.from(b)).toList(),
        checkoutKey: checkoutKey,
        settings: settings,
        onComplete: (r) {
          if (!mounted) return;
          setState(() {
            confirmation = r;
            bag.clear();
            checkoutKey = '';
          });
          load();
        },
      ),
    );
  }

  void compareProducts() {
    final selected = products.where((p) => compared.contains(p['id'])).toList();
    showDialog(
      context: context,
      builder: (c) => ComparisonView(
        products: selected,
        onChoose: (p) {
          Navigator.pop(c);
          detail(p);
        },
      ),
    );
  }

  dynamic _heroSecondaryProduct() {
    final primary = products[heroPrimaryIndex % products.length];
    final primaryImages = (primary['images'] as List?) ?? const [];
    if (heroTick % 4 == 3 && primaryImages.length > 1) return primary;
    return products[heroSecondaryIndex % products.length];
  }

  int _heroSecondaryImageIndex() {
    final product = _heroSecondaryProduct();
    final images = (product['images'] as List?) ?? const [];
    if (product == products[heroPrimaryIndex % products.length] &&
        images.length > 1) {
      return heroTick ~/ 4 % images.length;
    }
    return 0;
  }

  Widget _heroTile({
    required dynamic product,
    required int imageIndex,
    required bool large,
  }) {
    final productImages =
        (product['images'] as List?)?.cast<String>() ??
        <String>[product['image'] as String];
    final image = productImages[imageIndex % productImages.length];
    final displayed = {
      ...Map<String, dynamic>.from(product as Map),
      'image': image,
    };
    return GestureDetector(
      onTap: () => detail(product),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.16, 0),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.03, end: 1).animate(animation),
                child: child,
              ),
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey('${product['id']}:$image'),
            child: SizedBox.expand(child: photo(displayed)),
          ),
        ),
      ),
    );
  }

  Widget field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboard,
    bool obscure = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Please enter $label' : null,
    ),
  );
  void track() {
    final id = TextEditingController(), code = TextEditingController();
    Map<String, dynamic>? result;
    String problem = '';
    bool fetching = false;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, u) => AlertDialog(
          title: const Text('Track your order'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field(id, 'Order reference'),
                  field(code, 'Private tracking code'),
                  if (problem.isNotEmpty)
                    Text(problem, style: const TextStyle(color: Colors.red)),
                  if (result != null) ...[
                    Text(
                      result!['status'],
                      style: const TextStyle(fontSize: 26, color: green),
                    ),
                    Text(money(result!['total'])),
                    for (final line in result!['items'])
                      Text('${line['qty']} × ${line['name']}'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: fetching
                  ? null
                  : () async {
                      u(() => fetching = true);
                      try {
                        final r = await Api.call('track', {
                          'id': id.text.trim(),
                          'token': code.text.trim(),
                        });
                        if (c.mounted) {
                          u(() {
                            result = r;
                            problem = '';
                          });
                        }
                      } catch (e) {
                        if (c.mounted) u(() => problem = e.toString());
                      } finally {
                        if (c.mounted) u(() => fetching = false);
                      }
                    },
              child: const Text('Check status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget inventory() {
    if (Api.token.isEmpty) {
      final email = staffEmail;
      final password = staffPassword;
      return Center(
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title(
                  'A little order.\nA lot of possibility.',
                  'Sign in to Mary Inventory. Save visible products to publish them to your website.',
                ),
                field(
                  email,
                  'Email address',
                  keyboard: TextInputType.emailAddress,
                ),
                field(password, 'Password', obscure: true),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          await Api.signIn(email.text, password.text);
                          email.clear();
                          staffPassword.clear();
                          await load();
                        }),
                  child: Text(busy ? 'Signing in…' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final health = staffData['business_health'] as Map? ?? {};
    final allTimeReport = staffData['report'] as Map? ?? {};
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          title(
            page,
            page == 'Inventory'
                ? 'Your products, sizes and stock in one place.'
                : page == 'Orders'
                ? 'From the shopping cart to their doorstep.'
                : page == 'Reports'
                ? 'Real sales trends, margins and stock health.'
                : page == 'Messages'
                ? 'Read and respond to customer conversations.'
                : page == 'Transactions'
                ? 'Track PayChangu collections and payment attempts.'
                : 'Every stock change, with a reason.',
          ),
          if (page == 'Transactions')
            SizedBox(
              height: 650,
              child: TransactionsPanel(data: staffData, reload: load),
            )
          else if (page == 'Messages')
            SizedBox(height: 650, child: MessagesPanel(reload: load))
          else if (page == 'Operations')
            OperationsPanel(
              data: staffData,
              products: products,
              orders: orders,
              reload: load,
            )
          else if (page == 'Reports')
            ReportsPanel(data: staffData)
          else if (page == 'Inventory') ...[
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                stat('Products', '${products.length}'),
                stat(
                  'Units on hand',
                  '${products.fold<int>(0, (a, p) => a + stock(p))}',
                ),
                stat(
                  'Low-stock sizes',
                  '${products.fold<int>(0, (a, p) => a + (p['variants'] as Map).values.where((q) => q <= 3).length)}',
                ),
                stat(
                  'Stock at cost',
                  money(
                    products.fold<int>(
                      0,
                      (a, p) => a + stock(p) * (p['cost'] as int),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Business health', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                stat('Stock at cost', money(health['stock_cost_value'] ?? 0)),
                stat(
                  'Potential stock sales',
                  money(health['stock_retail_value'] ?? 0),
                ),
                stat('Margin rate', '${allTimeReport['margin_rate'] ?? 0}%'),
                stat(
                  'Low-stock options',
                  '${health['low_stock_variants'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search product or SKU',
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => editProduct(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final p in products.where((p) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              final haystack = [
                p['name'],
                p['id'],
                p['category'],
                p['description'],
                p['price'],
                p['regular_price'] ?? p['price'],
                p['cost'],
                (p['variants'] as Map?)?.keys.join(' '),
                (p['collections'] as List?)?.join(' '),
              ].join(' ').toString().toLowerCase();
              return haystack.contains(q);
            }))
              Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: SizedBox(width: 56, height: 64, child: photo(p)),
                  title: Text(p['name']),
                  subtitle: Text(
                    '${p['id']}  •  ${p['category']}  •  ${money(p['price'])}\n${stock(p)} in stock${p['active'] == 0 ? ' • Hidden from shop' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit product and stock',
                        onPressed: () => editProduct(p),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete product from website',
                        onPressed: () => deleteProduct(p),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ] else if (page == 'Orders') ...[
            if (orders.isEmpty)
              const Text(
                'No orders yet. Orders placed in the shop will appear here.',
              ),
            for (final o in orders)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            o['id'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(label: Text(o['status'])),
                        ],
                      ),
                      Text('${o['customer']} • ${o['phone']}'),
                      Text('${o['delivery']}: ${o['address']}'),
                      const SizedBox(height: 10),
                      for (final l in o['items'])
                        Text('${l['qty']} × ${l['name']} • ${l['variant']}'),
                      const SizedBox(height: 12),
                      Text(
                        '${money(o['total'])} • ${o['payment']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s
                              in (<String, List<String>>{
                                    'Placed': ['Packed', 'Cancelled'],
                                    'Packed': ['Dispatched', 'Cancelled'],
                                    'Dispatched': ['Completed'],
                                  })[o['status']] ??
                                  <String>[])
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() async {
                                      await Api.call('status', {
                                        'id': o['id'],
                                        'status': s,
                                      });
                                      await load();
                                    }),
                              child: Text(
                                s == 'Cancelled'
                                    ? 'Cancel & restock'
                                    : 'Mark $s',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            if (movements.isEmpty) const Text('No stock movements yet.'),
            for (final m in movements)
              Card(
                color: Colors.white,
                child: ListTile(
                  title: Text('${m['product']} • ${m['variant']}'),
                  subtitle: Text('${m['reason']}\n${m['created']} UTC'),
                  isThreeLine: true,
                  trailing: Text(
                    '${m['delta'] > 0 ? '+' : ''}${m['delta']}',
                    style: TextStyle(
                      fontSize: 23,
                      color: m['delta'] > 0 ? green : Colors.deepOrange,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget stat(String name, String value) => Container(
    width: 220,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe1e5dc)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 14, color: Color(0xff697469)),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
  Future<void> deleteProduct(dynamic p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text(
          'This removes ${p['name']} from the website and hides it in the shop. You can still find it in inventory history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete listing'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.call('product', {'id': p['id'], 'delete': true});
      await load();
      tell('Listing removed from the website.');
    } catch (e) {
      tell(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> editProduct(dynamic p) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditor(
        product: p == null ? null : Map<String, dynamic>.from(p),
      ),
    );
    if (changed == true) {
      await load();
      tell(
        'Product saved. Visible products update on the website within 15 seconds.',
      );
    }
  }
}
