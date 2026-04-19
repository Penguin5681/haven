import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_contact.dart';

class TrustedContactsStore {
  static const String _storageKey = 'trusted_contacts_v1';

  const TrustedContactsStore();

  Future<List<TrustedContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawContacts = prefs.getStringList(_storageKey) ?? const <String>[];

    final contacts = <TrustedContact>[];
    for (final rawContact in rawContacts) {
      try {
        final decoded = jsonDecode(rawContact);
        if (decoded is Map<String, dynamic>) {
          contacts.add(TrustedContact.fromJson(decoded));
        }
      } catch (_) {
        // Skip corrupted entries and preserve the rest of the list.
      }
    }

    return contacts;
  }

  Future<void> saveContacts(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = contacts
        .map((contact) => jsonEncode(contact.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, payload);
  }
}
