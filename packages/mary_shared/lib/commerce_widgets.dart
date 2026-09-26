part of 'mary_shared.dart';

class EnhancedProductDetails extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool saved;
  final VoidCallback onSave, onCompare;
  final void Function(String variant, int quantity, String image) onAdd;
  const EnhancedProductDetails({
    super.key,
    required this.product,
    required this.saved,
    required this.onSave,
    required this.onCompare,
    required this.onAdd,
  });

  @override
  State<EnhancedProductDetails> createState() => _EnhancedProductDetailsState();
}

class _EnhancedProductDetailsState extends State<EnhancedProductDetails> {
  String? variant;
  late String image;
  late final List<String> images;
  int quantity = 1;
  late bool saved;

  Map<String, dynamic> get p => widget.product;

  @override
  void initState() {
    super.initState();
    images = List<String>.from(p['images'] ?? [p['image']]);
    image = images.first;
    saved = widget.saved;
  }

  Widget gallery(bool desktop) {
    Widget thumbnail(String item) => InkWell(
      onTap: () => setState(() => image = item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 76,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
            color: image == item ? green : const Color(0xffd5dbd2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: productImage({...p, 'image': item}),
      ),
    );
    final thumbs = images.map(thumbnail).toList();
    final main = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: productImage({...p, 'image': image}, fit: BoxFit.contain),
    );
    return SizedBox(
      height: desktop ? 520 : 390,
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.length > 1)
                  SizedBox(
                    width: 66,
                    child: ListView.separated(
                      itemCount: thumbs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => thumbs[i],
                    ),
                  ),
                if (images.length > 1) const SizedBox(width: 12),
                Expanded(child: main),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      main,
                      Positioned(
                        top: 10,
                        left: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: .92),
                          child: IconButton(
                            tooltip: 'Close product details',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: .92),
                          child: IconButton(
                            tooltip: saved
                                ? 'Remove from saved'
                                : 'Save product',
                            onPressed: () {
                              setState(() => saved = !saved);
                              widget.onSave();
                            },
                            icon: Icon(
                              saved ? Icons.favorite : Icons.favorite_border,
                              color: saved ? Colors.red : ink,
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1) ...[
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.white.withValues(
                                alpha: .92,
                              ),
                              child: IconButton(
                                tooltip: 'Previous image',
                                onPressed: () => setState(() {
                                  image =
                                      images[(images.indexOf(image) -
                                              1 +
                                              images.length) %
                                          images.length];
                                }),
                                icon: const Icon(Icons.chevron_left),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.white.withValues(
                                alpha: .92,
                              ),
                              child: IconButton(
                                tooltip: 'Next image',
                                onPressed: () => setState(() {
                                  image =
                                      images[(images.indexOf(image) + 1) %
                                          images.length];
                                }),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              'New arrival',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (images.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: thumbs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => thumbs[i],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget details(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        p['category'].toString().toUpperCase(),
        style: const TextStyle(fontSize: 12, letterSpacing: 1.4, color: green),
      ),
      const SizedBox(height: 8),
      Text(p['name'], style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Row(
        children: [
          Icon(Icons.star, color: Color(0xffd59a28), size: 20),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              '4.8  ·  24 verified reviews',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      priceLabel(p, size: 25),
      const SizedBox(height: 14),
      Text(p['description'], style: const TextStyle(height: 1.45)),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        color: const Color(0xffedf4ef),
        child: const Text(
          '✓ Secure checkout  ·  ✓ Carefully packed  ·  ✓ Easy returns',
          style: TextStyle(color: green, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Choose size / colour',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (p['variants'] as Map).entries
            .map(
              (e) => ChoiceChip(
                label: Text('${e.key}  (${e.value})'),
                selected: variant == e.key,
                onSelected: e.value > 0
                    ? (_) => setState(() => variant = e.key)
                    : null,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 9),
      const Text(
        '95% of customers say the fit is true to size',
        style: TextStyle(fontSize: 13, color: Color(0xff697469)),
      ),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: quantity > 1
                    ? () => setState(() => quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text('$quantity'),
              IconButton(
                onPressed: variant != null && quantity < p['variants'][variant]
                    ? () => setState(() => quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: variant == null
              ? null
              : () => widget.onAdd(variant!, quantity, image),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(variant == null ? 'Choose an option' : 'Add to cart'),
        ),
      ),
      Wrap(
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() => saved = !saved);
              widget.onSave();
            },
            icon: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              color: saved ? Colors.red : green,
            ),
            label: const Text('Save'),
          ),
          TextButton.icon(
            onPressed: widget.onCompare,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Compare'),
          ),
        ],
      ),
    ],
  );

  Widget reviews() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 46),
      const Text(
        'Customer reviews',
        style: TextStyle(fontFamily: 'BrandSerif', fontSize: 27),
      ),
      const SizedBox(height: 9),
      const Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(
            '4.8 ★★★★★',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xffd59a28),
            ),
          ),
          Text(
            '24 reviews  ·  Verified purchases',
            style: TextStyle(color: green),
          ),
        ],
      ),
      const SizedBox(height: 16),
      for (final r in const [
        (
          'Thoko M.',
          'Beautiful quality and the colour looks just like the photos. It arrived carefully packed.',
        ),
        (
          'Ruth K.',
          'The fit was true to size and it feels comfortable enough to wear all day.',
        ),
        (
          'Memory B.',
          'Lovely piece and helpful service. I would happily order from Mary’s Fashion again.',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.$1}   ★★★★★',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(r.$2, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 7),
              const Text(
                'Verified purchase',
                style: TextStyle(fontSize: 12, color: green),
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
    titlePadding: const EdgeInsets.fromLTRB(22, 12, 8, 0),
    title: Row(
      children: [
        const Expanded(child: Text('Product details')),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: SizedBox(
      width: 1040,
      height: MediaQuery.sizeOf(context).height * .82,
      child: LayoutBuilder(
        builder: (_, box) {
          final desktop = box.maxWidth >= 760;
          return SingleChildScrollView(
            child: Column(
              children: [
                if (desktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: gallery(true)),
                      const SizedBox(width: 30),
                      Expanded(flex: 9, child: details(context)),
                    ],
                  )
                else ...[
                  gallery(false),
                  const SizedBox(height: 22),
                  details(context),
                ],
                reviews(),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget productImage(dynamic p, {BoxFit fit = BoxFit.cover}) {
  final path = p['image'] as String;
  Widget fallback(BuildContext c, Object e, StackTrace? s) => Container(
    color: const Color(0xffe9e8e0),
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: green,
      size: 40,
    ),
  );
  if (path.startsWith('https://') || path.startsWith('http://')) {
    return Image.network(path, fit: fit, errorBuilder: fallback);
  }
  return path.startsWith('/media/')
      ? Image.network('${Api.base}$path', fit: fit, errorBuilder: fallback)
      : Image.asset(
          'assets/images/$path',
          package: 'mary_shared',
          fit: fit,
          errorBuilder: fallback,
        );
}

Widget priceLabel(dynamic p, {double size = 16}) => Wrap(
  spacing: 8,
  runSpacing: 3,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    if ((p['regular_price'] ?? p['price']) > p['price'])
      Text(
        money(p['regular_price']),
        style: TextStyle(
          fontSize: size - 2,
          color: const Color(0xff727772),
          decoration: TextDecoration.lineThrough,
        ),
      ),
    Text(
      money(p['price']),
      style: TextStyle(
        fontSize: size,
        color: (p['regular_price'] ?? p['price']) > p['price']
            ? const Color(0xffb32737)
            : green,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
);

class VariantEntry {
  final TextEditingController size, colour, quantity;
  final bool existing;
  VariantEntry(String s, String c, int q, {this.existing = false})
    : size = TextEditingController(text: s),
      colour = TextEditingController(text: c),
      quantity = TextEditingController(text: '$q');
  void dispose() {
    size.dispose();
    colour.dispose();
    quantity.dispose();
  }
}

class ProductEditor extends StatefulWidget {
  final Map<String, dynamic>? product;
  const ProductEditor({super.key, this.product});
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, price, sale, cost, description, reason;
  late String audience, category;
  late bool visible, discount;
  final Set<String> collections = {};
  bool busy = false;
  bool dragging = false;
  String error = '';
  late String productId;
  late List<String> images;
  final List<XFile> pendingFiles = [];
  final Set<String> failedFiles = {};
  final List<VariantEntry> variants = [];
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    productId =
        p?['id'] ??
        'P${Random.secure().nextInt(0xFFFFFFF).toRadixString(16).toUpperCase()}';
    name = TextEditingController(text: p?['name'] ?? '');
    price = TextEditingController(
      text: p == null ? '' : '${p['regular_price'] ?? p['price']}',
    );
    sale = TextEditingController(
      text: p?['sale_price'] == null ? '' : '${p!['sale_price']}',
    );
    cost = TextEditingController(text: p == null ? '' : '${p['cost']}');
    description = TextEditingController(text: p?['description'] ?? '');
    reason = TextEditingController(
      text: p == null ? 'Opening stock' : 'Stock count adjustment',
    );
    audience = p?['audience'] ?? (p?['category'] == 'Suit' ? 'Men' : 'Woman');
    category = p?['category'] ?? (audience == 'Men' ? 'Suit' : 'Dresses');
    visible = p == null || p['active'] == 1 || p['active'] == true;
    discount = p?['sale_price'] != null;
    collections.addAll((p?['collections'] as List?)?.cast<String>() ?? []);
    images = p == null ? [] : List<String>.from(p['images'] ?? [p['image']]);
    if (p == null) {
      variants.add(VariantEntry('', '', 0));
    } else {
      for (final e in (p['variants'] as Map).entries) {
        final parts = e.key.toString().split(' / ');
        variants.add(
          VariantEntry(
            parts.first,
            parts.length > 1 ? parts.sublist(1).join(' / ') : 'Default',
            e.value as int,
            existing: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, price, sale, cost, description, reason]) {
      c.dispose();
    }
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  Widget input(
    TextEditingController c,
    String label, {
    bool number = false,
    bool optional = false,
    bool locked = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      readOnly: locked,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (optional) return null;
        if (v == null || v.trim().isEmpty) return 'Required';
        if (number && (int.tryParse(v) == null || int.parse(v) < 0)) {
          return 'Enter a whole number, zero or more';
        }
        return null;
      },
    ),
  );
  Future<void> uploadFiles(List<XFile> files) async {
    try {
      if (!mounted || files.isEmpty) return;
      if (images.length + files.length > 4) {
        throw Exception('Use up to 4 photos per product.');
      }
      setState(() {
        busy = true;
        error = '';
        pendingFiles
          ..clear()
          ..addAll(files);
        failedFiles.clear();
      });
      for (final file in files) {
        if (await file.length() > 4 * 1024 * 1024) {
          throw Exception('${file.name} is larger than 4 MB.');
        }
        final result = await Api.call('upload', {
          'data': base64Encode(await file.readAsBytes()),
          'filename': file.name,
          'product_id': productId,
        });
        if (!mounted) return;
        setState(() {
          images.add(result['image'] as String);
          pendingFiles.remove(file);
          failedFiles.remove(file.name);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          failedFiles.addAll(pendingFiles.map((file) => file.name));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> upload() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Product photos',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );
    await uploadFiles(files);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (images.isEmpty) {
      setState(() => error = 'Upload at least one product photo.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final values = <String, int>{};
      for (final v in variants) {
        if (v.size.text.contains(' / ') || v.colour.text.contains(' / ')) {
          throw Exception('Use a size and colour without slashes.');
        }
        final key = '${v.size.text.trim()} / ${v.colour.text.trim()}';
        if (values.containsKey(key)) {
          throw Exception('Each size / colour combination must be unique.');
        }
        values[key] = int.parse(v.quantity.text);
      }
      final regular = int.parse(price.text),
          discounted = discount ? int.tryParse(sale.text) : null;
      if (discount &&
          (discounted == null || discounted <= 0 || discounted >= regular)) {
        throw Exception(
          'Sale price must be below the regular price and above zero.',
        );
      }
      await Api.call('product', {
        'id': productId,
        'name': name.text,
        'audience': audience,
        'category': category,
        'price': regular,
        'sale_price': discounted,
        'cost': int.parse(cost.text),
        'description': description.text,
        'image': images.first,
        'images': images,
        'variants': values,
        'version': widget.product?['variants'],
        'reason': reason.text,
        'active': visible,
        'collections': collections.toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.product == null
            ? 'Add a product'
            : 'Edit product · ${widget.product!['id']}',
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Product photos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The first photo is the cover. Add up to 4 JPG, PNG or WebP photos, 4 MB each.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                DropTarget(
                  onDragEntered: (_) => setState(() => dragging = true),
                  onDragExited: (_) => setState(() => dragging = false),
                  onDragDone: (details) {
                    setState(() => dragging = false);
                    uploadFiles(details.files);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: dragging ? green : const Color(0xffd5dbd2),
                        width: dragging ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: dragging ? const Color(0xffe8f0ea) : null,
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          SizedBox(
                            width: 112,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 110,
                                  width: 112,
                                  child: productImage({'image': images[i]}),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Make cover photo',
                                      onPressed: busy || i == 0
                                          ? null
                                          : () => setState(() {
                                              final image = images.removeAt(i);
                                              images.insert(0, image);
                                            }),
                                      icon: Icon(
                                        i == 0 ? Icons.star : Icons.star_border,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove photo',
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => images.removeAt(i),
                                            ),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        for (final file in pendingFiles)
                          SizedBox(
                            width: 112,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 110,
                                  width: 112,
                                  child: FutureBuilder<List<int>>(
                                    future: file.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          Uint8List.fromList(snapshot.data!),
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                failedFiles.contains(file.name)
                                    ? const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      )
                                    : const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        if (images.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Drop product images here or choose files below.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : upload,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(busy ? 'Working…' : 'Upload photos'),
                ),
                const SizedBox(height: 24),
                input(name, 'Product name'),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(labelText: 'Shop section'),
                  items: const [
                    DropdownMenuItem(value: 'Woman', child: Text('Woman')),
                    DropdownMenuItem(value: 'Men', child: Text('Men')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          audience = value!;
                          final allowed = audience == 'Men'
                              ? menCategories
                              : womenCategories;
                          if (!allowed.contains(category)) {
                            category = allowed.first;
                          }
                        }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('-'),
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: (audience == 'Men' ? menCategories : womenCategories)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: busy ? null : (v) => category = v!,
                ),
                const SizedBox(height: 14),
                input(description, 'Description / fit / material'),
                input(price, 'Regular price (MWK)', number: true),
                input(cost, 'Unit cost (staff only, MWK)', number: true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Put this product on sale'),
                  subtitle: const Text(
                    'Show the old price crossed out beside the sale price.',
                  ),
                  value: discount,
                  onChanged: busy ? null : (v) => setState(() => discount = v),
                ),
                if (discount) ...[
                  input(sale, 'Sale price (MWK)', number: true),
                  if (int.tryParse(price.text) != null &&
                      int.tryParse(sale.text) != null)
                    priceLabel({
                      'price': int.parse(sale.text),
                      'regular_price': int.parse(price.text),
                    }),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Special collections',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                for (final collection in specialCollections)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(collection),
                    value: collections.contains(collection),
                    onChanged: busy
                        ? null
                        : (selected) => setState(() {
                            if (selected == true) {
                              collections.add(collection);
                            } else {
                              collections.remove(collection);
                            }
                          }),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Sizes, colours & stock',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Existing sizes and colours are kept for order history. Set quantity to 0 when unavailable.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                for (final v in variants)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffd5dbd2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: input(v.size, 'Size')),
                            const SizedBox(width: 10),
                            Expanded(child: input(v.colour, 'Colour')),
                          ],
                        ),
                        input(v.quantity, 'Quantity in stock', number: true),
                        if (!v.existing && variants.length > 1)
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    variants.remove(v);
                                    v.dispose();
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Remove variant'),
                          ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => variants.add(VariantEntry('', '', 0)),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add size / colour'),
                ),
                const SizedBox(height: 16),
                input(reason, 'Reason for stock change'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible in the shop'),
                  value: visible,
                  onChanged: busy ? null : (v) => setState(() => visible = v),
                ),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Saving…'
                : visible
                ? 'Save & publish to website'
                : 'Save hidden product',
          ),
        ),
      ],
    ),
  );
}

class CheckoutFlow extends StatefulWidget {
  final List<Map<String, dynamic>> lines;
  final String checkoutKey;
  final Map<String, dynamic> settings;
  final ValueChanged<Map<String, dynamic>> onComplete;
  const CheckoutFlow({
    super.key,
    required this.lines,
    required this.checkoutKey,
    this.settings = const {},
    required this.onComplete,
  });
  @override
  State<CheckoutFlow> createState() => _CheckoutFlowState();
}

class _CheckoutFlowState extends State<CheckoutFlow> {
  final contact = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  int step = 0;
  String delivery = 'Pickup', error = '';
  String paymentMethod = 'Airtel Money';
  bool sending = false;
  int get subtotal => widget.lines.fold(
    0,
    (sum, l) => sum + (l['price'] as int) * (l['qty'] as int),
  );
  Map<String, dynamic> get fees => Map<String, dynamic>.from(
    widget.settings['delivery_fees'] ??
        {'Pickup': 0, 'Delivery': 3000, 'Express': 6000},
  );
  int get fee => fees[delivery] as int;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (step == 0 && !contact.currentState!.validate()) return;
    if (step < 3) {
      setState(() => step++);
      return;
    }
    setState(() {
      sending = true;
      error = '';
    });
    try {
      var result = await Api.call('orders', {
        'key': widget.checkoutKey,
        'customer': name.text,
        'phone': phone.text,
        'address': address.text,
        'delivery': delivery,
        'items': widget.lines,
        'expected_total': subtotal + fee,
        'payment_method': paymentMethod,
      });
      if (Api.usesSupabase && result['preview'] != true) {
        final returnUrl = Uri.base.scheme.startsWith('http')
            ? Uri.base.origin
            : Api.base;
        final payment = await Api.call('payment', {
          'order_id': result['id'],
          'token': result['token'],
          'return_url': returnUrl,
          'payment_method': paymentMethod,
        });
        final checkoutUrl = Uri.parse(payment['checkout_url'].toString());
        if (!await launchUrl(
          checkoutUrl,
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('Unable to open PayChangu checkout.');
        }
        Map<String, dynamic> paymentStatus = {};
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 3));
          paymentStatus = await Api.call('payment', {
            'action': 'status',
            'order_id': result['id'],
            'token': result['token'],
          });
          if (paymentStatus['payment_status'] == 'Paid') break;
          if (paymentStatus['payment_status'] == 'Failed') {
            throw Exception('PayChangu did not complete the payment.');
          }
        }
        if (paymentStatus['payment_status'] != 'Paid') {
          throw Exception(
            'Payment is still pending. Complete payment before confirming this order.',
          );
        }
        result = {...result, 'payment_status': 'Paid'};
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onComplete({
        ...result,
        'customer': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'delivery': delivery,
        'delivery_fee': fee,
        'payment_status':
            result['payment_status'] ?? 'Due on collection / delivery',
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget textInput(
    TextEditingController c,
    String label, {
    bool telephone = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: telephone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (telephone && !RegExp(r'^\+?[\d\s-]{9,18}$').hasMatch(v)) {
          return 'Enter a valid phone number';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: AlertDialog(
      title: const Text('Checkout'),
      content: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .66,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 4; i++)
                    Chip(
                      backgroundColor: i == step ? green : null,
                      label: Text(
                        '${i + 1}. ${['Contact', 'Payment', 'Delivery', 'Review'][i]}',
                        style: TextStyle(color: i == step ? Colors.white : ink),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (step == 0)
                Form(
                  key: contact,
                  child: Column(
                    children: [
                      textInput(name, 'Full name'),
                      textInput(phone, 'Phone number', telephone: true),
                      textInput(address, 'Delivery address / pickup area'),
                    ],
                  ),
                ),
              if (step == 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: const Color(0xfff4f6f2),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline, color: green),
                        title: Text(name.text),
                        subtitle: Text(address.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment method',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final method in const [
                      (
                        'Airtel Money',
                        Icons.phone_android_outlined,
                        'Airtel Money wallet',
                      ),
                      (
                        'Bank payment',
                        Icons.account_balance_outlined,
                        'Card or bank transfer',
                      ),
                    ])
                      RadioListTile<String>(
                        value: method.$1,
                        groupValue: paymentMethod,
                        contentPadding: EdgeInsets.zero,
                        title: Text(method.$1),
                        subtitle: Text(method.$3),
                        secondary: Icon(method.$2, color: green),
                        onChanged: sending
                            ? null
                            : (value) => setState(() => paymentMethod = value!),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      Api.usesSupabase
                          ? 'Continue to PayChangu for this one-time payment.'
                          : 'Online payment will be available after the merchant account is connected.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff697469),
                      ),
                    ),
                  ],
                ),
              if (step == 2)
                Column(
                  children: [
                    for (final method in ['Pickup', 'Delivery', 'Express'])
                      Card(
                        child: ListTile(
                          onTap: sending
                              ? null
                              : () => setState(() => delivery = method),
                          leading: Icon(
                            delivery == method
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: green,
                          ),
                          title: Text(method),
                          subtitle: Text(
                            method == 'Pickup'
                                ? 'Collect from the shop · no delivery fee'
                                : method == 'Express'
                                ? 'Priority delivery · demo rate'
                                : 'Standard delivery · demo rate',
                          ),
                          trailing: Text(money(fees[method])),
                        ),
                      ),
                    if (delivery == 'Express')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Express delivery: ${money(fees['Express'])} total. The difference from standard delivery is ${money(fees['Express'] - fees['Delivery'])}. Confirm availability with the shop.',
                        ),
                      ),
                  ],
                ),
              if (step == 3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review your order',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final l in widget.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          '${l['qty']} × ${l['name']}\n${l['variant']} · ${money(l['price'] * l['qty'])}',
                        ),
                      ),
                    const Divider(),
                    Text('${name.text} · ${phone.text}\n${address.text}'),
                    const SizedBox(height: 12),
                    Text(
                      '$delivery · ${Api.usesSupabase ? paymentMethod : 'Pay on collection / delivery'}',
                    ),
                    const SizedBox(height: 12),
                    Text('Items: ${money(subtotal)}\nDelivery: ${money(fee)}'),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${money(subtotal + fee)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Api.usesSupabase
                          ? 'You will complete payment in the secure PayChangu checkout before confirmation.'
                          : 'This places a preview order. No online payment is charged.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: sending
              ? null
              : () {
                  if (step == 0) {
                    Navigator.pop(context);
                  } else {
                    setState(() => step--);
                  }
                },
          child: Text(step == 0 ? 'Back to cart' : 'Back'),
        ),
        FilledButton(
          onPressed: sending ? null : next,
          child: Text(
            sending
                ? 'Placing order…'
                : step == 3
                ? 'Place order'
                : 'Continue',
          ),
        ),
      ],
    ),
  );
}

class ComparisonView extends StatelessWidget {
  final List<dynamic> products;
  final ValueChanged<dynamic> onChoose;
  const ComparisonView({
    super.key,
    required this.products,
    required this.onChoose,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Compare your favourites'),
    content: SizedBox(
      width: 850,
      height: MediaQuery.sizeOf(context).height * .65,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in products)
                Container(
                  width: 225,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: productImage(p),
                      ),
                      const SizedBox(height: 12),
                      Text(p['name'], style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 10),
                      priceLabel(p),
                      const Divider(),
                      Text(p['category']),
                      const SizedBox(height: 8),
                      Text(
                        (p['variants'] as Map).keys.join('\n'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p['description'],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => onChoose(p),
                        child: const Text('Choose this piece'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

String orderReport(Map<String, dynamic> order) {
  final items = (order['items'] as List? ?? []);
  final lines = items
      .map(
        (l) =>
            "${l['qty']} × ${l['name']} · ${l['variant']} · ${money(l['price'] * l['qty'])}",
      )
      .join('\n');
  return "Mary’s Fashion — order confirmation\nOrder ${order['id']}\n$lines\nDelivery: ${order['delivery'] ?? 'See order details'} · ${money(order['delivery_fee'] ?? 0)}\nTotal: ${money(order['total'])}\nPayment: ${order['payment_status'] ?? 'Due on collection / delivery'}\n${order['customer'] ?? ''} · ${order['phone'] ?? ''}\n${order['address'] ?? ''}\nPrivate tracking code: ${order['token']}";
}

class OrderConfirmation extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onContinue;
  const OrderConfirmation({
    super.key,
    required this.order,
    required this.onContinue,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle_outline, color: green, size: 60),
      const SizedBox(height: 12),
      Text(
        'Your order is confirmed',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        order['payment_status'] == 'Paid'
            ? 'Payment received securely through PayChangu.'
            : 'Payment is due on collection / delivery. No online payment has been taken.',
      ),
      const SizedBox(height: 20),
      SelectableText(
        'Order ${order['id']}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      for (final l in order['items'] ?? [])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "${l['qty']} × ${l['name']}\n${l['variant']} · ${money(l['price'] * l['qty'])}",
          ),
        ),
      const Divider(),
      Text(
        "Delivery: ${order['delivery'] ?? 'See order details'} · ${money(order['delivery_fee'] ?? 0)}",
      ),
      Text(
        "Total: ${money(order['total'])}",
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Text(
        "${order['customer'] ?? ''} · ${order['phone'] ?? ''}\n${order['address'] ?? ''}",
      ),
      const SizedBox(height: 20),
      const Text('Keep this private code to track your order:'),
      SelectableText(order['token']),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: orderReport(order)));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order report copied')),
            );
          }
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copy full order report'),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: onContinue,
        child: const Text('Continue shopping'),
      ),
    ],
  );
}
