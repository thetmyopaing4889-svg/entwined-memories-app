import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/memory_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await MemoryService.loadCreatorName();
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = 'v${info.version} (${info.buildNumber})';
    } catch (_) {
      version = '';
    }
    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _version = version;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await MemoryService.saveCreatorName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('သိမ်းပြီးပြီ ✨'),
          backgroundColor: Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Setting သိမ်းမရသေးဘူး: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Entwined Memories',
      applicationVersion: _version.isEmpty ? null : _version,
      applicationIcon: const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFE8A0B4),
        size: 34,
      ),
      children: const [
        Text(
          'A quiet memory home for the moments a family never wants to lose.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.child_care_outlined,
                          color: Color(0xFFE8A0B4),
                        ),
                        title: const Text('Child profile'),
                        subtitle: const Text('Name, birthday and photo'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openProfile,
                      ),
                      const Divider(height: 1, indent: 68),
                      ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: Color(0xFFE8A0B4),
                        ),
                        title: const Text('About the app'),
                        subtitle: const Text('Version and project story'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAbout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('သင့်နာမည် (Dad / Mom)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D2C33))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Dad / Mom / နာမည်',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Memory အသစ် ထည့်တဲ့အခါ ဒီနာမည် "Added by" အနေနဲ့ ပြပါလိမ့်မယ်',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A0B4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('သိမ်းမယ်',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline,
                      color: Color(0xFFE8A0B4)),
                  title: const Text('Entwined Memories'),
                  subtitle: Text(_version.isEmpty
                      ? 'For My Baby 💕'
                      : '$_version · For My Baby 💕'),
                ),
              ],
            ),
    );
  }
}
