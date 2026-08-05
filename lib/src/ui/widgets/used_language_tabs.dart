import 'package:flutter/material.dart';

import '../../i18n/language_registry.dart';
import '../theme.dart';

class UsedLanguageTabs extends StatelessWidget {
  const UsedLanguageTabs({
    super.key,
    required this.registry,
    required this.usedCodes,
    required this.selectedCode,
    required this.onSelected,
  });

  final LanguageRegistry registry;
  final List<String> usedCodes;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final code in usedCodes)
          ChoiceChip(
            label: Text(code.toUpperCase()),
            selected: code == selectedCode,
            onSelected: (_) => onSelected(code),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
          onPressed: () => _showPicker(context),
        ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final unused = registry.languages
        .where(
          (language) => language.active && !usedCodes.contains(language.code),
        )
        .toList();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _LanguagePicker(languages: unused),
    );
    if (selected != null) onSelected(selected);
  }
}

class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({required this.languages});
  final List<LanguageInfo> languages;

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.toLowerCase();
    final filtered = widget.languages.where((language) {
      return language.code.toLowerCase().contains(normalized) ||
          language.name.toLowerCase().contains(normalized) ||
          language.nativeName.toLowerCase().contains(normalized);
    }).toList();
    return AlertDialog(
      title: const Text('Add language'),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search languages',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No unused active languages',
                        style: TextStyle(color: Hs.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final language = filtered[index];
                        return ListTile(
                          title: Text(language.nativeName),
                          subtitle: Text('${language.name} · ${language.code}'),
                          onTap: () => Navigator.pop(context, language.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
