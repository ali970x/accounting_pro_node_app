import "package:flutter/material.dart";

import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/local/local_store.dart";
import "../../core/local/sync_service.dart";
import "../../widgets/modern_card.dart";

class SyncPage extends StatefulWidget {
  final ApiClient api;

  const SyncPage({
    super.key,
    required this.api,
  });

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final store = LocalStore();

  bool loading = true;
  bool syncing = false;
  String? error;
  String? lastMessage;
  int pending = 0;
  String? lastSyncAt;

  @override
  void initState() {
    super.initState();
    loadLocalCounts();
  }

  Future<void> loadLocalCounts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      pending = await store.pendingCount();
      lastSyncAt = await store.getLastSyncAt();
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> syncNow() async {
    setState(() {
      syncing = true;
      error = null;
      lastMessage = null;
    });

    try {
      final service = SyncService(api: widget.api, store: store);
      final result = await service.syncNow();
      lastMessage = result.message;
      await loadLocalCounts();
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);

    return RefreshIndicator(
      onRefresh: loadLocalCounts,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            c.isArabic ? "المزامنة" : "Sync",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ModernCard(
            padding: const EdgeInsets.all(22),
            child: loading
                ? const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.sync_rounded)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.isArabic ? "حالة البيانات" : "Data status", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                Text(lastSyncAt == null ? "-" : lastSyncAt!),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(c.isArabic ? "بانتظار الرفع: $pending" : "Pending changes: $pending"),
                      if (lastMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(lastMessage!),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: syncing ? null : syncNow,
                          icon: syncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync),
                          label: Text(c.isArabic ? "مزامنة الآن" : "Sync Now"),
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
