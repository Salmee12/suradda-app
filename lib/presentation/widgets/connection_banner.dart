import 'package:flutter/material.dart';
import '../viewmodels/room_connection.dart';

/// Banner shown inside a party screen once the live connection has dropped.
///
/// Renders nothing while the connection is healthy, so it can be dropped into a
/// column unconditionally.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.connection,
    required this.onRetry,
    required this.onLeave,
  });

  final RoomConnection connection;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (!connection.isBroken) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final reconnecting = connection == RoomConnection.reconnecting;
    final background =
        reconnecting ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground =
        reconnecting ? scheme.onTertiaryContainer : scheme.onErrorContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (reconnecting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          else
            Icon(Icons.cloud_off, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reconnecting
                  ? 'Connection lost — trying to rejoin the party...'
                  : 'Disconnected from the party. Playback is no longer in sync.',
              style: TextStyle(fontSize: 12, color: foreground),
            ),
          ),
          if (!reconnecting) ...[
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: const Text('Reconnect'),
            ),
            TextButton(
              onPressed: onLeave,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: const Text('Leave'),
            ),
          ],
        ],
      ),
    );
  }
}
