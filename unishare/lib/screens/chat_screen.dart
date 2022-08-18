import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:unishare/models/connection.dart';
import 'package:unishare/models/socket_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:unishare/widgets/file_pick.dart';
import '../widgets/chat_info.dart';
import '../widgets/chat_text.dart';
import 'package:path_provider/path_provider.dart';

// ignore: must_be_immutable
class ChatScreen extends StatefulWidget {
  ChatScreen({Key? key, required String room})
      : roomId = room,
        super(key: key);
  String roomId;
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  bool _offer = false;
  bool _isAudioEnabled = true;
  //RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer(); // for Video Call
  final TextEditingController inputController = TextEditingController();
  List<ChatInfo> messageList = [];
  late IO.Socket socket;
  bool refresshVideoList = true;
  RTCDataChannel? sendchanell;
  RTCDataChannel? receiveChannel;
  RTCDataChannel? receivechanell;
  RTCDataChannelInit? _dataChannelDict;
  FilePickerResult? result;
  late Uint8List item;
  Uint8List? bytesData;
  //final String socketId = "1011";

  final Map<String, dynamic> configuration = {
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
      {
        "url": 'turn:192.158.29.39:3478?transport=udp',
        "credential": 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
        "username": '28224511:1379330808'
      }
    ]
  };

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true, //for video call
    },
    "optional": [],
  };

  Map<String, Connection> connections =
      {}; // All Peer Connection will be stored here.

  //These are for manual testing without a heroku server

  @override
  dispose() {
    //To stop multiple calling websocket, use the following code.
    if (socket.disconnected) {
      socket.disconnect();
    }
    socket.disconnect();
    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    //print(widget.roomId);
    initSocket();
    super.initState();
  }

  void initSocket() {
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false,
    });
    socket.connect();
    socket.on('connect', (_) {
      print('Connected id : ${socket.id}');
    });

    socket.onConnect((data) async {
      print('Socket Server Successfully connected');
      socket.emit("join", widget.roomId);
    });

    //Offer received from other client which is set as remote description and answer is created and transmitted
    socket.on("receiveOffer", (data) async {
      //print("Offer received");
      SocketId id = SocketId.fromJson(data["socketId"]);
      await remoteConnection(id);
      String sdp = write(data["session"], null);

      RTCSessionDescription description = RTCSessionDescription(sdp, 'offer');

      await connections[id.destinationId]!
          .peer
          .setRemoteDescription(description);

      RTCSessionDescription description2 =
          await connections[id.destinationId]!.peer.createAnswer({
        //'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1
      }); // {'offerToReceiveVideo': 1 for video call

      var session = parse(description2.sdp.toString());

      connections[id.destinationId]!.peer.setLocalDescription(description2);
      socket
          .emit("createAnswer", {"session": session, "socketId": id.toJson()});
      setState(() {
        refresshVideoList = !refresshVideoList;
      });
    });
    //Answer received from originating client which is set as remote description
    socket.on("receiveAnswer", (data) async {
      //print("Answer received");
      String sdp = write(data["session"], null);

      RTCSessionDescription description = RTCSessionDescription(sdp, 'answer');

      await connections[data["socketId"]["destinationId"]]!
          .peer
          .setRemoteDescription(description);
      setState(() {
        refresshVideoList = !refresshVideoList;
      });
    });

    //Candidate received from answerer which is added to the peer connection
    //THIS COMPELETES THE CONNECTION PROCEDURE
    socket.on("receiveCandidate", (data) async {
      print("Candidate received");
      dynamic candidate = RTCIceCandidate(data['candidate']['candidate'],
          data['candidate']['sdpMid'], data['candidate']['sdpMlineIndex']);
      await connections[data['socketId']['destinationId']]!
          .peer
          .addCandidate(candidate);
    });

    socket.on("userDisconnected", (id) async {
      await connections[id]!.renderer.dispose();
      await connections[id]!.peer.close();
      connections.remove(id);
    });

    socket.onConnectError((data) {
      //print(data);
    });
  }

// Created connection by Caller by pressing connect button
  Future<void> _createConnection(id) async {
    //print("Create connection");
    connections[id.destinationId] =
        Connection(); // Adding key and value to Collection list.
    connections[id.destinationId]!.renderer = RTCVideoRenderer();
    await connections[id.destinationId]!.renderer.initialize();
    connections[id.destinationId]!.peer =
        await createPeerConnection(configuration, offerSdpConstraints);
    connections[id.destinationId]!.peer.addStream(_localStream!);
    //Creating Sender Datachanell
    _dataChannelDict = RTCDataChannelInit();
    _dataChannelDict!.id = 1;
    _dataChannelDict!.ordered = true;
    _dataChannelDict!.maxRetransmitTime = -1;
    _dataChannelDict!.maxRetransmits = -1;
    _dataChannelDict!.protocol = 'sctp';
    _dataChannelDict!.negotiated = false;
    sendchanell = await connections[id.destinationId]!
        .peer
        .createDataChannel("SendCnanell", _dataChannelDict!);
    sendchanell!.onMessage = (message) async {
      print("Message from Remote");
      if (message.type == MessageType.text) {
        print(message.text);
        ChatInfo data = ChatInfo(
            message: message.text, sender: "Sohel Rana", time: "12.00 AM");
        setState(() {
          messageList.add(data);
        });
      } else {
        print(message.binary);

        setState(() {
          bytesData = message.binary;
        });
        //writeToDirectory(bytesData);
        //List<int> bytelist = bytesData.toList();
        // File originalFile =
        //     await File("joining_letter.docx").writeAsBytes(bytelist);
        // print(originalFile.length());
      }
    };
    sendchanell!.onDataChannelState = (state) => {print(state)};

    //Creating Receiver Datachanell
    // connections[id.destinationId]!.peer.onDataChannel = receiveChannelCallback;

    //The below onIceCandidate will not call if you are a caller
    connections[id.destinationId]!.peer.onIceCandidate = (e) {
      print("On-ICE Candidate is Finding");
      //Transmitting candidate data from answerer to caller
      if (e.candidate != null && !_offer) {
        socket.emit("sendCandidate", {
          "candidate": {
            'candidate': e.candidate.toString(),
            'sdpMid': e.sdpMid.toString(),
            'sdpMlineIndex': e.sdpMLineIndex,
          },
          "socketId": id.toJson(),
        });
      }
    };

    connections[id.destinationId]!.peer.onIceConnectionState = (e) {
      print(e);
    };

    connections[id.destinationId]!.peer.onAddStream = (stream) {
      //print('addStream: ' + stream.id);
      connections[id.destinationId]!.renderer.srcObject =
          stream; //same as the _remoteRenderer.srcObject = stream
    };
  }

  // Creating connection by recever automatically by socket event
  Future<void> remoteConnection(id) async {
    //print("Create connection");
    connections[id.destinationId] =
        Connection(); // Adding key and value to Collection list.
    connections[id.destinationId]!.renderer = RTCVideoRenderer();
    await connections[id.destinationId]!.renderer.initialize();
    connections[id.destinationId]!.peer =
        await createPeerConnection(configuration, offerSdpConstraints);
    connections[id.destinationId]!.peer.addStream(_localStream!);
    //Creating Sender Datachanell
    // _dataChannelDict = RTCDataChannelInit();
    // _dataChannelDict!.id = 1;
    // _dataChannelDict!.ordered = true;
    // _dataChannelDict!.maxRetransmitTime = -1;
    // _dataChannelDict!.maxRetransmits = -1;
    // _dataChannelDict!.protocol = 'sctp';
    // _dataChannelDict!.negotiated = true;
    // sendchanell = await connections[id.destinationId]!
    //     .peer
    //     .createDataChannel("receive", _dataChannelDict!);
    // sendchanell!.onDataChannelState = (state) => {print(state)};

    //Creating Receiver Datachanell
    connections[id.destinationId]!.peer.onDataChannel = receiveChannelCallback;

    //The below onIceCandidate will not call if you are a caller
    connections[id.destinationId]!.peer.onIceCandidate = (e) {
      print("On-ICE Candidate is Finding");
      //Transmitting candidate data from answerer to caller
      if (e.candidate != null && !_offer) {
        socket.emit("sendCandidate", {
          "candidate": {
            'candidate': e.candidate.toString(),
            'sdpMid': e.sdpMid.toString(),
            'sdpMlineIndex': e.sdpMLineIndex,
          },
          "socketId": id.toJson(),
        });
      }
    };

    connections[id.destinationId]!.peer.onIceConnectionState = (e) {
      print(e);
    };

    connections[id.destinationId]!.peer.onAddStream = (stream) {
      //print('addStream: ' + stream.id);
      connections[id.destinationId]!.renderer.srcObject =
          stream; //same as the _remoteRenderer.srcObject = stream
    };
  }

  initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize(); // for video call
    _localStream = await _getUserMedia();
  }

  //Get audio stream and save to local
  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      //'video': false,
      'video': {
        'facingMode': 'user',
      }, //If you want to make video calling app.
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;

    return stream;
  }

// Handle incoming message

  void receiveChannelCallback(RTCDataChannel dataChannel) {
    receiveChannel = dataChannel;
    dataChannel.onMessage = (message) async {
      print("Message from Local");

      if (message.type == MessageType.text) {
        print(message.text);
        ChatInfo data = ChatInfo(
            message: message.text, sender: "Sohel Rana", time: "12.00 AM");
        setState(() {
          messageList.add(data);
        });
      } else {
        print(message.binary);
        setState(() {
          bytesData = message.binary;
        });
        //writeToDirectory(bytesData);
        // List<int> bytelist = bytesData.toList();
        // File originalFile =
        //     await File("joining_letter.docx").writeAsBytes(bytelist);
        // print(originalFile);
      }
    };
  }

  Future<void> createOffer(id) async {
    RTCSessionDescription description =
        await connections[id.destinationId]!.peer.createOffer({
      //'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1
    }); //{'offerToReceiveVideo': 1} for video call
    var session = parse(description.sdp.toString());
    socket.emit("createOffer", {"session": session, "socketId": id.toJson()});
    setState(() {
      _offer = true;
    });

    connections[id.destinationId]!.peer.setLocalDescription(description);
  }

//This is the method that initiates the connection
  void _createOfferAndConnect() async {
    socket.emitWithAck("newConnect", widget.roomId, ack: (data) async {
      print(
          "OriginId: ${data["originId"]}, DestinationIds: ${data["destinationIds"]}");

      data["destinationIds"].forEach((destinationId) async {
        if (connections[destinationId] == null) {
          SocketId id = SocketId(
              originId: data["originId"], destinationId: destinationId);
          await _createConnection(id);
          await createOffer(id);
        }
      });
      // await _createConnection(socketId);
      // await createOffer(socketId);
    });
  }

  //enable audio
  void _enableAudio() async {
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = true;
    });
  }

  //disable audio
  void _disableAudio() async {
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = false;
    });
  }

  // Codes for Video Call Grid
  List<Widget> renderStreamsGrid() {
    List<Widget> allRemoteVideo = [];

    connections.forEach((key, value) {
      allRemoteVideo.add(
        SizedBox(
          child: Container(
            width: 250,
            height: 200,
            color: Colors.yellow,
            child: RTCVideoView(
              value.renderer,
              // objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              // mirror: true,
            ),
          ),
        ),
      );

      //allRemoteVideo.add(value.renderer);
    });

    return allRemoteVideo;
  }
  //Save Incoming Files to Document Directory

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/sohelrana.jpg');
  }

  Future<File> writeToDirectory(Uint8List image) async {
    final file = await _localFile;

    // Write the file
    //return file.writeAsBytes(image);
    //final file = File('${(await getTemporaryDirectory()).path}/$path');
    await file.writeAsBytes(
        image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes));
    print(file.path);

    return file;
  }

  //Send File Handler
  sendFileHandler() {
    RTCDataChannelMessage binaryMessage =
        RTCDataChannelMessage.fromBinary(item);
    _offer
        ? sendchanell!.send(binaryMessage)
        : receiveChannel!.send(binaryMessage);
  }

  //Chat Input Handler

  inputHandler() {
    //add local message to chatlist
    ChatInfo data = ChatInfo(
        message: inputController.text, sender: "Sohel Rana", time: "12.00 AM");
    setState(() {
      messageList.add(data);
    });
    //Send Local message to Remote
    String messageText = inputController.text;
    RTCDataChannelMessage textMessage = RTCDataChannelMessage(messageText);
    _offer ? sendchanell!.send(textMessage) : receiveChannel!.send(textMessage);

    //inputController.text = "";

    inputController.text = "";
  }

  @override
  Widget build(BuildContext context) {
    // return WillPopScope(
    //   onWillPop: () async {
    //     socket.disconnect();
    //     await _localRenderer.dispose();
    //     for (var key in connections.keys) {
    //       await connections[key]!.renderer.dispose();
    //       await connections[key]!.peer.close();
    //       connections.remove(key);
    //     }
    //     return true;
    //   },
    return Scaffold(
      appBar: AppBar(
        title: const Text("unishare"),
      ),

      //Video Calling Area Start

      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    //key: const Key("local"),
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.blue,
                    child: RTCVideoView(_localRenderer),
                  ),
                  Container(
                    height: 300,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        //itemCount: renderStreamsGrid().length,
                        itemCount: renderStreamsGrid().length,
                        itemBuilder: (context, index) {
                          return renderStreamsGrid()[index];
                        }),
                  ),

                  // Positioned(
                  //   left: 10,
                  //   bottom: 20,
                  //   child: ListView.builder(
                  //       scrollDirection: Axis.horizontal,
                  //       shrinkWrap: true,
                  //       itemCount: renderStreamsGrid().length,
                  //       itemBuilder: (context, index) {
                  //         return renderStreamsGrid()[index];
                  //       }),
                  // ),

                  Positioned(
                    width: 1199,
                    height: 60,
                    top: 20,
                    left: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          //height: 50,
                          width: 200,
                          child: ElevatedButton(
                            onPressed: _createOfferAndConnect,
                            child: const Text('Connect'),
                          ),
                        ),
                        const SizedBox(
                          width: 50,
                        ),
                        SizedBox(
                            //height: 50,
                            width: 150,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_isAudioEnabled) {
                                  _disableAudio();
                                } else {
                                  _enableAudio();
                                }
                                setState(() {
                                  _isAudioEnabled = !_isAudioEnabled;
                                });
                              },
                              child: Text(
                                  'Mic is ${_isAudioEnabled == true ? "on" : "off"}'),
                            ))
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // *******Chat Area Started from here************

            Container(
              width: 300,
              color: Colors.white54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                        child: SingleChildScrollView(
                      // Focus Last Chat in Screen https://stackoverflow.com/questions/64926183/how-can-i-focus-the-last-item-of-a-listview-in-flutter
                      reverse: true,
                      child: ListView.builder(
                          itemCount: messageList.length,
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) => _offer
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: ChatText(
                                      message: "${messageList[index].message}"),
                                )
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: ChatText(
                                      message: "${messageList[index].message}"),
                                )),
                    )),
                  ),
                  if (bytesData != null)
                    Image.memory(
                      bytesData!,
                      width: 250,
                      height: 200,
                    ),
                  if (result != null)
                    FilePick(
                      result: result,
                    ),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: inputController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  //labelText: "Type your message",
                                  hintText: "Type message..",
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            ElevatedButton(
                                child: Text("Send"), onPressed: inputHandler),
                            const SizedBox(
                              width: 10,
                            ),
                            ElevatedButton(
                                child: Text("Send file"),
                                onPressed: sendFileHandler),
                            const SizedBox(
                              width: 10,
                            ),
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: () async {
                                result = await FilePicker.platform.pickFiles(
                                    //allowMultiple: false,
                                    //type: FileType.any
                                    );
                                if (result == null) {
                                  print("No file selected");
                                } else {
                                  setState(() {
                                    item = result!.files[0].bytes!;
                                  });
                                  result?.files.forEach((element) {
                                    //print(item);
                                    //print(element.name);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
        // const SizedBox(
        //   width: double.infinity,
        //   height: 40,
        // ),
      ),
      // Video Calling Area End
    );
    //);
  }
}
