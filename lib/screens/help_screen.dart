import 'package:flutter/material.dart';
// No external providers required for static help content

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: const TextStyle(height: 1.4)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & How‑to')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView(
            children: [
              // Quick search / index
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search help topics',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (v) {},
              ),
              const SizedBox(height: 12),

              // Quick Start
              _sectionTitle(context, 'Quick Start'),
              _paragraph(
                'Get started quickly: register medicines, manage inventory, run reports, use AI Chat, and review audits.',
              ),

              // Sections as accordions
              ExpansionTile(
                title: const Text('Register a medicine'),
                children: [
                  ListTile(
                    title: const Text('Steps'),
                    subtitle: const Text(
                      '1) Tap Register → 2) Fill name, quantity, expiry, optional photo → 3) Save.\nRequired: name, quantity. Use batch/notes for extra info. The app checks duplicates by name and batch.',
                    ),
                  ),
                  ListTile(
                    title: const Text('Tips'),
                    subtitle: const Text(
                      'Use the photo feature to reduce mistakes; add expiry to get expiring reports.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Inventory management'),
                children: [
                  ListTile(
                    title: const Text('Search & filters'),
                    subtitle: const Text(
                      'Use search to find medicines. Use filters for low stock, expired, or category.',
                    ),
                  ),
                  ListTile(
                    title: const Text('Editing items'),
                    subtitle: const Text(
                      'Tap an item to edit quantity, expiry, or notes. Mark as out‑of‑stock when unavailable.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Using AI Chat'),
                children: [
                  ListTile(
                    title: const Text('What it can do'),
                    subtitle: const Text(
                      'Ask for inventory summaries, report suggestions, or how to handle expiring stock. Not a substitute for professional medical advice.',
                    ),
                  ),
                  ListTile(
                    title: const Text('Example prompts'),
                    subtitle: const Text(
                      '"Show soonest expiring medicines"\n"How to handle expired stock"\n"Create a report of low stock items"',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Reports'),
                children: [
                  ListTile(
                    title: const Text('Available reports'),
                    subtitle: const Text(
                      'Expiring items, stock history, sales (if enabled). Use filters and export CSV/PDF.',
                    ),
                  ),
                  ListTile(
                    title: const Text('Exporting'),
                    subtitle: const Text(
                      'Tap Export in Reports to download CSV or PDF. Use scheduled exports in Settings if available.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Audit page'),
                children: [
                  ListTile(
                    title: const Text('Understanding the audit'),
                    subtitle: const Text(
                      'Shows who did what and when. Columns: user, action, item, timestamp. Use filters to find changes and restore when possible.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Trash & recovery'),
                children: [
                  ListTile(
                    title: const Text('Restore or delete'),
                    subtitle: const Text(
                      'Trashed items expire after the retention period. Restore items from Trash or choose to permanently delete.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Notifications & alerts'),
                children: [
                  ListTile(
                    title: const Text('What alerts mean'),
                    subtitle: const Text(
                      'Notifications include expiring soon, deleted items, and low stock alerts. Tap notifications to view related items.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('Settings overview'),
                children: [
                  ListTile(
                    title: const Text('Theme, backup, privacy'),
                    subtitle: const Text(
                      'Adjust appearance, enable backups, and manage privacy options in Settings.',
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text('FAQ / Troubleshooting'),
                children: [
                  ListTile(
                    title: const Text('Common fixes'),
                    subtitle: const Text(
                      'App not syncing: check network and account. Notifications not arriving: ensure permissions and enable notifications in Settings.',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact & feedback
              _sectionTitle(context, 'Contact & Feedback'),
              _paragraph(
                'Report bugs, request features, or send feedback via the Contact screen.',
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.contact_page_outlined),
                label: const Text('Contact Support'),
                onPressed: () => Navigator.of(context).pushNamed('/contact'),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Tip: Use the search box to quickly find help topics.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
