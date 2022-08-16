import 'dart:ui';

import 'package:flutter/material.dart';

class ChatText extends StatefulWidget {
  final String? message;
  const ChatText({Key? key, required this.message}) : super(key: key);

  @override
  _ChatTextState createState() => _ChatTextState();
}

class _ChatTextState extends State<ChatText> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          "${widget.message}",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
