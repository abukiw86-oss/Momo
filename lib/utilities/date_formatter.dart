class DateFormatter {
  String formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return '';

    int ts = timestamp is int
        ? timestamp
        : int.tryParse(timestamp.toString()) ?? 0;
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
    Duration diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
