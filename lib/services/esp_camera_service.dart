class EspCameraService {
  String _ipAddress = "10.112.131.205"; // Default Static IP
  final String _streamPath = "/stream"; // Common MJPEG path for ESP32-CAM

  void setIpAddress(String ip) {
    _ipAddress = ip;
  }

  String get streamUrl {
    // Ensure no double slashes if user adds one
    final cleanIp = _ipAddress.endsWith('/') 
        ? _ipAddress.substring(0, _ipAddress.length - 1) 
        : _ipAddress;
        
    // Handle http prefix
    final baseUrl = cleanIp.startsWith('http') ? cleanIp : 'http://$cleanIp';
    
    return "$baseUrl$_streamPath";
  }

  String get baseUrl {
     final cleanIp = _ipAddress.endsWith('/') 
        ? _ipAddress.substring(0, _ipAddress.length - 1) 
        : _ipAddress;
    return cleanIp.startsWith('http') ? cleanIp : 'http://$cleanIp';
  }
}
