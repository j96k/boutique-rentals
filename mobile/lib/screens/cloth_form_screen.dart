
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Add a new cloth, or edit one when [cloth] is given. Pops with the saved Cloth.
class ClothFormScreen extends StatefulWidget {
  const ClothFormScreen({super.key, this.cloth, this.initialCode});
  final Cloth? cloth;
  final String? initialCode;

  @override
  State<ClothFormScreen> createState() => _ClothFormScreenState();
}

class _ClothFormScreenState extends State<ClothFormScreen> {
  static const categories = ['Lehenga', 'Saree', 'Gown', 'Sherwani', 'Kurta', 'Indo-western', 'Blazer', 'Jewellery'];

  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.cloth?.code ?? widget.initialCode ?? '');
  late final _name = TextEditingController(text: widget.cloth?.name ?? '');
  late final _desc = TextEditingController(text: widget.cloth?.description ?? '');
  late final _category = TextEditingController(text: widget.cloth?.category ?? '');
  late final _size = TextEditingController(text: widget.cloth?.size ?? '');
  late final _price = TextEditingController(
      text: widget.cloth == null || widget.cloth!.rentPrice == 0 ? '' : widget.cloth!.rentPrice.toStringAsFixed(0));
  Uint8List? _imageBytes;
  String? _imageName;
  bool _busy = false;

  bool get _editing => widget.cloth != null;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = x.name;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}', error: true);
    }
  }

  void _choosePhoto() {
    if (kIsWeb) {
      _pick(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: AppColors.plum),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.plum),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final saved = await Api.instance.saveCloth(
        id: widget.cloth?.id,
        fields: {
          'cloth_code': _code.text.trim(),
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'category': _category.text.trim(),
          'size': _size.text.trim(),
          'rent_price': _price.text.trim().isEmpty ? '0' : _price.text.trim(),
        },
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      if (!mounted) return;
      showSnack(context, _editing ? 'Saved ✓' : '${saved.code} added to wardrobe ✓');
      Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit cloth' : 'New cloth')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(_editing ? 'Save changes' : 'Add to wardrobe'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          GestureDetector(
            onTap: _choosePhoto,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                if (_imageBytes != null)
                  ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                else if (widget.cloth?.imageUrl != null)
                  ClothImage(widget.cloth!.imageUrl, radius: 24)
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.gold, width: 1.6),
                    ),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, size: 46, color: AppColors.plumSoft),
                      SizedBox(height: 8),
                      Text('Add a photo', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.plum)),
                      Text('so anyone can recognise it', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                if (_imageBytes != null || widget.cloth?.imageUrl != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.edit_rounded, color: AppColors.plum),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
            decoration: const InputDecoration(
              labelText: 'Cloth ID *',
              hintText: 'e.g. LH001',
              helperText: 'The unique code on the tag. Customers & staff search by this.',
              prefixIcon: Icon(Icons.sell_rounded),
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Cloth ID is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Red bridal lehenga'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories
                .map((c) => ActionChip(
                      label: Text(c),
                      backgroundColor: _category.text == c ? AppColors.goldSoft : Colors.white,
                      onPressed: () => setState(() => _category.text = c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _size,
                decoration: const InputDecoration(labelText: 'Size', hintText: 'S / M / 38'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rent price', prefixText: '₹ '),
                validator: (v) => (v ?? '').trim().isNotEmpty && double.tryParse(v!.trim()) == null ? 'Number only' : null,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _desc,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Colour, fabric, work, what is included (dupatta, jewellery)…',
              alignLabelWithHint: true,
            ),
          ),
        ]),
      ),
    );
  }
}
