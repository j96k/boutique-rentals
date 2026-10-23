import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/server_settings.dart';
import '../widgets/donate_dialog.dart';
import 'customer_screen.dart';
import 'feedback_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Api.instance.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.plumDeep, AppColors.plumSoft]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.gold,
              child: Text((u?.boutiqueName ?? 'B').characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.plumDeep)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u?.boutiqueName ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('@${u?.username ?? ''}', style: const TextStyle(color: Colors.white70)),
                if (u?.phone != null) Text(u!.phone!, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              const Text('Your Boutique code for customers',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Customers open the app, tap "I\'m a customer", and enter this code + the Cloth ID to check if a dress is free.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(width: 160, height: 160, child: QrImageView(data: u?.username ?? '')),
              const SizedBox(height: 6),
              SelectableText(u?.username ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lightbulb_rounded, color: AppColors.gold),
              title: const Text('Ideas & requests'),
              subtitle: const Text('Ask for changes or new features — any language'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: AppColors.overdue),
              title: const Text('Support us (donate)'),
              subtitle: const Text('This app is free — donations help us build more'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showDonateDialog(context),
            ),
            if (u?.isAdmin ?? false) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.plum),
                title: const Text('All requests (admin)'),
                subtitle: const Text("Read and answer every boutique's requests"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeedbackScreen())),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_search_rounded, color: AppColors.plum),
              title: const Text('Open customer view'),
              subtitle: const Text('See what your customers see'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CustomerScreen(initialBoutique: u?.username))),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dns_rounded, color: AppColors.plum),
              title: const Text('Server address'),
              subtitle: Text(Api.instance.baseUrl),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showServerSettings(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.overdue),
              title: const Text('Logout', style: TextStyle(color: AppColors.overdue, fontWeight: FontWeight.w700)),
              onTap: () async {
                if (!await confirm(context, 'Logout?', 'You will need your password to login again.')) return;
                await Api.instance.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                }
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
