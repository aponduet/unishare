// import 'package:flutter/material.dart';
// import 'package:unishare/widgets/chat_info.dart';
// import 'package:unishare/widgets/chat_text.dart';

// class ChatArea extends StatefulWidget {
//   const ChatArea({Key? key}) : super(key: key);

//   @override
//   _ChatAreaState createState() => _ChatAreaState();
// }

// class _ChatAreaState extends State<ChatArea> {
//   final TextEditingController _imputController = TextEditingController();
//   List<ChatInfo> messageList = [];

//   inputHandler() {
//     ChatInfo data = ChatInfo(
//         message: _imputController.text, sender: "Sohel Rana", time: "12.00 AM");
//     setState(() {
//       messageList.add(data);
//     });
//     _imputController.text = "";
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 300,
//       color: Colors.white54,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Expanded(
//             child: Container(
//                 child: SingleChildScrollView(
//               // Focus Last Chat in Screen https://stackoverflow.com/questions/64926183/how-can-i-focus-the-last-item-of-a-listview-in-flutter
//               reverse: true,
//               child: ListView.builder(
//                   itemCount: messageList.length,
//                   scrollDirection: Axis.vertical,
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   itemBuilder: (context, index) =>
//                       ChatText(message: "${messageList[index].message}")),
//             )),
//           ),
//           SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: Padding(
//                 padding: const EdgeInsets.all(10.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _imputController,
//                         decoration: const InputDecoration(
//                           border: OutlineInputBorder(),
//                           //labelText: "Type your message",
//                           hintText: "Type message..",
//                         ),
//                       ),
//                     ),
//                     const SizedBox(
//                       width: 10,
//                     ),
//                     ElevatedButton(child: Text("Send"), onPressed: inputHandler)
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }
