import 'package:flutter_webrtc/flutter_webrtc.dart';

class Connector {
  RTCDataChannelInit get dcConfig {
    var dcConfig = RTCDataChannelInit();
    dcConfig.negotiated = true;
    dcConfig.id = 1001;
    return dcConfig;
  }
}
