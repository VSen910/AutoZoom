import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    Key? key,
    required this.image,
  }) : super(key: key);

  final XFile image;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.file(File(widget.image.path))
            ),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade900
                  ),
                  onPressed: () async {
                    await GallerySaver.saveImage(widget.image.path);
                    Fluttertoast.showToast(
                      msg: 'Image saved to \'Pictures\'',
                      toastLength: Toast.LENGTH_SHORT,
                    );
                  },
                  child: const Text('Save image'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
