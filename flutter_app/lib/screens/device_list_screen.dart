import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../providers/playback_provider.dart';
import 'playback_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-discover on entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().discover();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.selectDeviceTitle),
        actions: [
          IconButton(
            icon: deviceProvider.scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: deviceProvider.scanning
                ? null
                : () => deviceProvider.refresh(),
            tooltip: s.rescan,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      body: _buildBody(context, deviceProvider, s),
    );
  }

  Widget _buildBody(
      BuildContext context, DeviceProvider deviceProvider, S s) {
    if (deviceProvider.scanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(s.scanningDevices, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (deviceProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(deviceProvider.error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => deviceProvider.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(s.retry),
            ),
          ],
        ),
      );
    }

    if (deviceProvider.devices.isEmpty) {
      final hasDiscoveryError = deviceProvider.discoveryError != null;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: hasDiscoveryError
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasDiscoveryError ? Icons.wifi_off : Icons.tv_off,
                  size: 40,
                  color: hasDiscoveryError
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hasDiscoveryError ? s.networkTroubleshootTitle : s.noDevicesFound,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                hasDiscoveryError ? s.networkTroubleshootHint : s.noDevicesHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (hasDiscoveryError) ...[
                const SizedBox(height: 16),
                _buildTroubleshootingTips(context, s),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => deviceProvider.refresh(),
                icon: const Icon(Icons.refresh),
                label: Text(s.scanAgain),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: deviceProvider.devices.length,
          separatorBuilder: (context2, index2) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final device = deviceProvider.devices[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectDevice(context, index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tv,
                          size: 24,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.friendlyName,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              device.deviceUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTroubleshootingTips(BuildContext context, S s) {
    final tips = <String>[
      s.networkTipCheckNetwork,
      s.networkTipSameNetwork,
      if (Platform.isMacOS) s.networkTipLocalNetwork,
      if (Platform.isWindows) s.networkTipFirewallWindows,
      if (!Platform.isWindows) s.networkTipFirewall,
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDevice(BuildContext context, int index) async {
    final deviceProvider = context.read<DeviceProvider>();
    final playbackProvider = context.read<PlaybackProvider>();

    final selected = await deviceProvider.selectDevice(index);
    if (!selected) {
      if (context.mounted && deviceProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deviceProvider.error!)),
        );
      }
      return;
    }

    // Cast and navigate to playback
    if (!context.mounted) return;
    final casted = await playbackProvider.cast();
    if (casted && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PlaybackScreen(),
        ),
      );
    } else if (context.mounted && playbackProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(playbackProvider.error!)),
      );
    }
  }
}
