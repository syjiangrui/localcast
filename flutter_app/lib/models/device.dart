class DlnaDevice {
  final int index;
  final String friendlyName;
  final String deviceUrl;

  DlnaDevice({
    required this.index,
    required this.friendlyName,
    required this.deviceUrl,
  });

  factory DlnaDevice.fromJson(Map<String, dynamic> json) {
    return DlnaDevice(
      index: json['index'] as int,
      friendlyName: json['friendly_name'] as String,
      deviceUrl: json['device_url'] as String,
    );
  }
}
