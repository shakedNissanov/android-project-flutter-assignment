import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'main.dart';
import 'dart:async';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;

final SnappingSheetController _snappingSheetController = SnappingSheetController();

class PreviewPage extends StatefulWidget {
  @override
  _PreviewPageState createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body:
        SnappingSheet(
          controller: _snappingSheetController,
          lockOverflowDrag: true,
          snappingPositions: [
            SnappingPosition.factor(
              positionFactor: 0.0,
              grabbingContentOffset: GrabbingContentOffset.top,
            ),
            SnappingPosition.factor(
              snappingCurve: Curves.elasticOut,
              snappingDuration: Duration(milliseconds: 1750),
              positionFactor: 0.5,
            ),
            SnappingPosition.factor(positionFactor: 0.9),
          ],
          child: RandomWords(),
          grabbingHeight: 75,
          grabbing: DefaultGrabbing(),
          sheetBelow: SnappingSheetContent(
            draggable: true,
            child: Content(),
          ),
        ),
    );
  }
}

class DefaultGrabbing extends StatefulWidget {
  @override
  _DefaultGrabbingState createState() => _DefaultGrabbingState();
}

class _DefaultGrabbingState extends State<DefaultGrabbing> {
  bool isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            spreadRadius: 10,
            color: Colors.black.withOpacity(0.15),
          )
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Welcome back, " + email!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.arrow_upward),
                onPressed: () {
                  if(isOpen == false) {
                    _snappingSheetController.snapToPosition(
                      SnappingPosition.factor(positionFactor: 0.2),
                    );
                  }
                  else {
                    _snappingSheetController.snapToPosition(SnappingPosition.factor(
                      positionFactor: 0.0,
                      grabbingContentOffset: GrabbingContentOffset.top,
                    ));
                  }
                  isOpen = !isOpen;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Content extends StatefulWidget {
  @override
  _ContentState createState() => _ContentState();
}

class _ContentState extends State<Content> {
  File? _image;
  List<Asset> list = <Asset>[];

  Future<File> getImageFileFromAssets(Asset asset) async {
    final byteData = await asset.getByteData();

    final tempFile =
    File("${(await getTemporaryDirectory()).path}/${asset.name}");
    final file = await tempFile.writeAsBytes(
      byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );

    return file;
  }

  Future<void> downloadFileExample() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    File? downloadToFile = File('${appDocDir.path}/' + email!);

    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('pictures/' + email!)
          .writeToFile(downloadToFile);
    }
    on firebase_core.FirebaseException catch(e) {
      downloadToFile = null;
    }
    setState(() {
      _image = downloadToFile;
    });
  }

  Future<void> uploadFile(File? image) async {
    await firebase_storage.FirebaseStorage.instance
        .ref('pictures/' + email!)
        .putFile(image!);
  }

  Future getImage() async {
    final noPictureSnackbar = SnackBar(content: Text('No image selected'));
    try {
      list = await MultiImagePicker.pickImages(
        maxImages: 1,
        enableCamera: true,
      );
    } on Exception catch (e) {

    }
    getImageFileFromAssets(list[0]).then((value) =>
        setState(() {
          if(_image == null) {
            _image = value;
          }
          else {
            if (_image!.path == value.path) {
              ScaffoldMessenger.of(context).showSnackBar(noPictureSnackbar);
            }
            else {
              _image = value;
              uploadFile(_image);
            }
          }
        }));
  }

  @override
  void initState() {
    super.initState();
    downloadFileExample().then((value) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 40,
                backgroundImage: (_image == null) ?
                    NetworkImage('https://exoffender.org/wp-content/uploads/2016/09/empty-profile.png')
                    : Image.file(_image!).image,
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    email!,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      getImage();
                      setState(() {

                      });
                    },
                    child: Text("Change avatar"),
                  ),
                )
              ],
            ),
          ]
        ),
      ),
    );
  }
}

