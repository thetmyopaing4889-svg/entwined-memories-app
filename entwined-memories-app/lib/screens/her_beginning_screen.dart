import 'package:flutter/material.dart';
import '../models/child_profile.dart';
import '../services/profile_service.dart';

class HerBeginningScreen extends StatefulWidget {
  final ChildProfile profile;

  const HerBeginningScreen({super.key, required this.profile});

  @override
  State<HerBeginningScreen> createState() => _HerBeginningScreenState();
}

class _HerBeginningScreenState extends State<HerBeginningScreen> {
  late ChildProfile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  String _formatBirthday(DateTime? date) {
    if (date == null) return 'Birthday not added yet';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _profile.name.trim().isEmpty ? 'Your baby' : _profile.name.trim();
    final age = _profile.birthday == null
        ? 'Every chapter starts with love.'
        : _formatAge(_profile.birthday!);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text('Her Beginning'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _editStory,
            tooltip: 'Edit story',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDCE7), Color(0xFFFFF0F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: _profile.photoUrl != null &&
                      _profile.photoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_profile.photoUrl!),
                      fit: BoxFit.cover,
                      colorFilter: const ColorFilter.mode(
                        Colors.black26,
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: _profile.photoUrl == null || _profile.photoUrl!.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.child_care_rounded,
                      size: 84,
                      color: Color(0xFFE8A0B4),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            _profile.beginningTitle?.trim().isNotEmpty == true
                ? _profile.beginningTitle!.trim()
                : 'The day $name began',
            style: const TextStyle(
              color: Color(0xFF3D2C33),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _profile.beginningSubtitle?.trim().isNotEmpty == true
                ? _profile.beginningSubtitle!.trim()
                : 'A small beginning. A lifetime of memories.',
            style: TextStyle(
              color: Color(0xFF8B3A52),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.cake_outlined,
            label: 'Birthday',
            value: _formatBirthday(_profile.birthday),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.favorite_outline,
            label: 'Growing beautifully',
            value: age,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              _profile.beginningStory?.trim().isNotEmpty == true
                  ? _profile.beginningStory!.trim()
                  : 'This is a quiet place for the first pages of her story — '
                      'the little details, the first smiles, and all the love '
                      'that surrounded her from the very beginning.',
              style: TextStyle(
                color: Color(0xFF3D2C33),
                fontSize: 16,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editStory() async {
    final updated = await Navigator.push<ChildProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => HerBeginningEditScreen(profile: _profile),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _profile = updated;
      _saving = false;
    });
  }

  String _formatAge(DateTime birthday) {
    final now = DateTime.now();
    var months = (now.year - birthday.year) * 12 + now.month - birthday.month;
    if (now.day < birthday.day) months -= 1;
    if (months <= 0) {
      final days = now.difference(birthday).inDays.clamp(0, 99999).toInt();
      return days == 1 ? '1 day of wonder' : '$days days of wonder';
    }
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) {
      return remainingMonths == 1
          ? '1 month of wonder'
          : '$remainingMonths months of wonder';
    }
    if (remainingMonths == 0) {
      return years == 1 ? '1 year of wonder' : '$years years of wonder';
    }
    final yearLabel = years == 1 ? '1 year' : '$years years';
    final monthLabel =
        remainingMonths == 1 ? '1 month' : '$remainingMonths months';
    return '$yearLabel $monthLabel of wonder';
  }
}

class HerBeginningEditScreen extends StatefulWidget {
  final ChildProfile profile;

  const HerBeginningEditScreen({super.key, required this.profile});

  @override
  State<HerBeginningEditScreen> createState() => _HerBeginningEditScreenState();
}

class _HerBeginningEditScreenState extends State<HerBeginningEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _storyController;
  late final TextEditingController _birthPlaceController;
  late final TextEditingController _birthWeightController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _titleController = TextEditingController(text: profile.beginningTitle);
    _subtitleController =
        TextEditingController(text: profile.beginningSubtitle);
    _storyController = TextEditingController(text: profile.beginningStory);
    _birthPlaceController = TextEditingController(text: profile.birthPlace);
    _birthWeightController = TextEditingController(text: profile.birthWeight);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _storyController.dispose();
    _birthPlaceController.dispose();
    _birthWeightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = widget.profile;
    final updated = ChildProfile(
      name: profile.name,
      birthday: profile.birthday,
      photoUrl: profile.photoUrl,
      coverPhotoUrl: profile.coverPhotoUrl,
      beginningTitle: _titleController.text.trim(),
      beginningSubtitle: _subtitleController.text.trim(),
      beginningStory: _storyController.text.trim(),
      birthPlace: _birthPlaceController.text.trim(),
      birthWeight: _birthWeightController.text.trim(),
    );
    try {
      await ProfileService.saveProfile(updated);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Her Beginning သိမ်းမရသေးဘူး: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF3D2C33),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(title: const Text('Write Her Beginning')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          const Text(
            'ဒီစာတွေကို မိသားစုအတွက် ကိုယ်တိုင်ရေးထားနိုင်ပါတယ်။ နောက်မှ ပြန်ပြင်လို့လည်းရပါတယ်။',
            style: TextStyle(
              color: Color(0xFF8B3A52),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _label('Story title'),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('ဥပမာ - The day our little love began'),
          ),
          const SizedBox(height: 18),
          _label('Short introduction'),
          TextField(
            controller: _subtitleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('ဥပမာ - A small beginning...'),
          ),
          const SizedBox(height: 18),
          _label('Her story'),
          TextField(
            controller: _storyController,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('သူမရဲ့ ပထမဆုံးနေ့အကြောင်း ရေးပါ'),
          ),
          const SizedBox(height: 18),
          _label('Born at (optional)'),
          TextField(
            controller: _birthPlaceController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('ဆေးရုံ / နေရာ'),
          ),
          const SizedBox(height: 18),
          _label('Birth weight (optional)'),
          TextField(
            controller: _birthWeightController,
            decoration: _decoration('ဥပမာ - 3.2 kg'),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8A0B4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Her Beginning',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE6ED),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFB05070), size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB0889A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF3D2C33),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}