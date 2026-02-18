import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
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
                : () => deviceProvider.discover(),
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: _buildBody(context, deviceProvider),
    );
  }

  Widget _buildBody(BuildContext context, DeviceProvider deviceProvider) {
    if (deviceProvider.scanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for DLNA devices...'),
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
              onPressed: () => deviceProvider.discover(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (deviceProvider.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No DLNA devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your TV is on and connected to the same network',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => deviceProvider.discover(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: deviceProvider.devices.length,
      itemBuilder: (context, index) {
        final device = deviceProvider.devices[index];
        return ListTile(
          leading: const Icon(Icons.tv),
          title: Text(device.friendlyName),
          subtitle: Text(device.deviceUrl),
          onTap: () => _selectDevice(context, index),
        );
      },
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
