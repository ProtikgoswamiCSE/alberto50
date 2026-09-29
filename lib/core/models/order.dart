import 'package:intl/intl.dart';

class MemberOrder {
  final int id;
  final String code;
  final int userId;
  final int membershipId;
  final String membershipName;
  final String total;
  final String status;
  final DateTime? timestamp;
  final String gateway;

  const MemberOrder({
    required this.id,
    required this.code,
    required this.userId,
    required this.membershipId,
    required this.membershipName,
    required this.total,
    required this.status,
    this.timestamp,
    required this.gateway,
  });

  factory MemberOrder.fromJson(Map<String, dynamic> json) {
    DateTime? ts;
    final tsRaw = json['timestamp'] ?? json['modified'];
    if (tsRaw != null) {
      ts = DateTime.tryParse(tsRaw.toString());
    }
    return MemberOrder(
      id: _toInt(json['id']),
      code: json['code'] as String? ?? '',
      userId: _toInt(json['user_id']),
      membershipId: _toInt(json['membership_id']),
      membershipName: json['membership_name'] as String? ?? '',
      total: json['total']?.toString() ?? '0',
      status: json['status'] as String? ?? '',
      timestamp: ts,
      gateway: json['gateway'] as String? ?? '',
    );
  }

  String get formattedDate {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM d, yyyy').format(timestamp!);
  }

  String get formattedTotal {
    final amount = double.tryParse(total) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
