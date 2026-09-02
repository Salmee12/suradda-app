/// Live-connection state of a listening party, shared by the online and
/// hotspot ViewModels.
///
/// The UI must never infer "connected" from the mere presence of a room or a
/// host object: a socket can die silently while that state is still populated,
/// which is exactly the bug this enum exists to prevent.
enum RoomConnection {
  /// Not in a party.
  idle,

  /// First connection attempt is in flight.
  connecting,

  /// Socket is open and traffic is flowing.
  connected,

  /// Socket dropped and automatic retries are in flight.
  reconnecting,

  /// Socket dropped and automatic retries were exhausted.
  disconnected,
}

extension RoomConnectionX on RoomConnection {
  bool get isLive => this == RoomConnection.connected;

  /// True when the party is nominally joined but not actually reachable — the
  /// state the UI has to surface instead of pretending everything is fine.
  bool get isBroken =>
      this == RoomConnection.reconnecting ||
      this == RoomConnection.disconnected;
}
