import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../utils.dart';

/// Network image of a cloth with a tasteful placeholder.
class ClothImage extends StatelessWidget {
  const ClothImage(this.path, {super.key, this.radius = 16, this.iconSize = 36});
  final String? path;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.goldSoft, Color(0xFFEFE3F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(Icons.checkroom_rounded, size: iconSize, color: AppColors.plumSoft)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: path == null
          ? placeholder
          : Image.network(
              Api.instance.imageUrl(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (c, child, p) => p == null ? child : placeholder,
            ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});
  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forStatus(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppColors.icon(status), size: dense ? 13 : 16, color: c),
        const SizedBox(width: 4),
        Text(AppColors.label(status),
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 13)),
      ]),
    );
  }
}

/// The cloth ID shown like a stitched garment tag.
class CodeTag extends StatelessWidget {
  const CodeTag(this.code, {super.key, this.light = false});
  final String code;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: 0.18) : AppColors.goldSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: light ? Colors.white54 : AppColors.gold, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sell_rounded, size: 13, color: light ? Colors.white : AppColors.plum),
        const SizedBox(width: 4),
        Text(code,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 12,
              color: light ? Colors.white : AppColors.plum,
            )),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.plum),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Oops',
        subtitle: message,
        action: SizedBox(width: 160, child: OutlinedButton(onPressed: onRetry, child: const Text('Try again'))),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: AppColors.muted)),
          ),
          ?trailing,
        ]),
      );
}

/// A phone number / Gmail / Instagram ID you can copy with one tap
/// (then paste it into the dialer, WhatsApp, Gmail or Instagram).
class CopyText extends StatelessWidget {
  const CopyText(this.value, {super.key, required this.what, this.icon, this.light = false, this.fontSize = 13});
  final String value;
  final String what; // "Phone number", "Gmail", "Instagram ID" — for the "copied" message
  final IconData? icon;
  final bool light; // on a dark background
  final double fontSize;

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) showSnack(context, '$what copied: $value');
    } catch (_) {
      // Some browsers block copying; show the value so it can be typed.
      if (context.mounted) showSnack(context, "Couldn't copy here — $what: $value", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.goldSoft : AppColors.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 2, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: fontSize)),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Copy',
            child: Icon(Icons.copy_rounded, size: fontSize + 1, color: light ? Colors.white : AppColors.plumSoft),
          ),
        ]),
      ),
    );
  }
}
