import 'package:flutter/material.dart';
import '../services/soul_pack.dart';

class SoulPackScreen extends StatefulWidget {
  const SoulPackScreen({super.key});

  @override
  State<SoulPackScreen> createState() => _SoulPackScreenState();
}

class _SoulPackScreenState extends State<SoulPackScreen> {
  List<SoulPack> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packs = await SoulPackManager.loadPacks();
    setState(() {
      _packs = packs;
      _loading = false;
    });
  }

  Future<void> _togglePack(SoulPack pack) async {
    await SoulPackManager.setActive(pack.domain, !pack.active);
    // Reload engine with new active pack (future enhancement)
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soul-Packs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _packs.length,
              itemBuilder: (_, i) {
                final pack = _packs[i];
                return SwitchListTile(
                  title: Text(pack.name, style: const TextStyle(color: Colors.tealAccent)),
                  subtitle: Text('${pack.description}\n${pack.wordCount} terms'),
                  value: pack.active,
                  onChanged: (_) => _togglePack(pack),
                );
              },
            ),
    );
  }
}
