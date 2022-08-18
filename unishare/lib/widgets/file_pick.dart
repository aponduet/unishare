import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FilePick extends StatefulWidget {
  final FilePickerResult? result;
  const FilePick({
    Key? key,
    this.result,
  }) : super(key: key);

  @override
  State<FilePick> createState() => _FilePickState();
}

class _FilePickState extends State<FilePick> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected file:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ListView.builder(
              shrinkWrap: true,
              itemCount: widget.result?.files.length ?? 0,
              itemBuilder: (context, index) {
                return Text(widget.result?.files[index].name ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold));
              })
        ],
      ),
    );
  }
}
