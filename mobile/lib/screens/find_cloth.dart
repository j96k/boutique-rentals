import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../utils.dart';
import 'cloth_detail_screen.dart';
import 'cloth_form_screen.dart';

/// Look up a cloth by its exact ID and open it. Offers to add it if missing.
Future<void> openClothByCode(BuildContext context, String code, {VoidCallback? onChanged}) async {
  code = code.trim().toUpperCase();
  if (code.isEmpty) return;
  try {
    final cloth = await Api.instance.clothByCode(code);
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: cloth.id)));
    onChanged?.call();
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (e.statusCode == 404) {
      final add = await confirm(context, 'Not found', 'No cloth with ID "$code".\nDo you want to add it now?',
          ok: 'Add cloth');
      if (add && context.mounted) {
        final saved = await Navigator.push(
            context, MaterialPageRoute(builder: (_) => ClothFormScreen(initialCode: code)));
        if (saved != null) onChanged?.call();
      }
    } else {
      showSnack(context, e.message, error: true);
    }
  }
}
