import 'package:auto_zoom2/screens/image_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';


class Home extends StatefulWidget {
  const Home({Key? key, required this.cameras}) : super(key: key);

  final List<CameraDescription> cameras;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late CameraController _cameraController;
  ObjectDetector? objectDetector;

  bool shutterAvailable = true;
  double maxZoom = 1;
  double zoomVal = 1;

  int _imageCount = 0;

  InputImage toInputImage(CameraImage cameraImage) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    final InputImageRotation? imageRotation =
        InputImageRotationValue.fromRawValue(
            widget.cameras[0].sensorOrientation);

    final InputImageFormat? inputImageFormat =
        InputImageFormatValue.fromRawValue(cameraImage.format.raw);

    final planeData = cameraImage.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
  }

  // bool isRectValid(Rect rect) {
  //   double rectLeft = rect.left;
  //   double rectTop = rect.top;
  //   double rectRight = rect.right;
  //   double rectBottom = rect.bottom;
  //
  //   double rectCenterX = (rectLeft + rectRight) / 2;
  //   double rectCenterY = (rectTop + rectBottom) / 2;
  //
  //   Size? previewSize = _cameraController.value.previewSize;
  //
  //   double cameraCenterX = previewSize!.width / 2;
  //   double cameraCenterY = previewSize!.height / 2;
  //
  //   double threshold = previewSize.width / 4;
  //   double distanceToCenter = sqrt(pow(rectCenterX - cameraCenterX, 2) +
  //       pow(rectCenterY - cameraCenterY, 2));
  //
  //   return distanceToCenter < threshold;
  // }

  void _setCamera() {
    _cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.high);
    _cameraController.initialize().then((value) async {
      if (!mounted) {
        return;
      }
      _cameraController.setFocusMode(FocusMode.auto);
      maxZoom = await _cameraController.getMaxZoomLevel();
      _cameraController.startImageStream((image) async {
        startImageStream(image);
      });
      setState(() {});
    }).catchError((e) {
      if (kDebugMode) {
        print(e);
      }
    });
  }

  void startImageStream(CameraImage image) async {
    _imageCount++;
    if (_imageCount % 10 == 0) {
      final inputImage = toInputImage(image);
      final List<DetectedObject> objects =
          await objectDetector!.processImage(inputImage);

      for (DetectedObject detectedObject in objects) {
        final rect = detectedObject.boundingBox;

        // var imageFile = File();
        // var decodedImage = await decodeImageFromList(
        //     imageFile.readAsBytesSync());

        // final rectPercent = Rect.fromLTRB(
        //   rect.left / _cameraController.value.previewSize!.width,
        //   rect.top / _cameraController.value.previewSize!.height,
        //   rect.right / _cameraController.value.previewSize!.width,
        //   rect.bottom / _cameraController.value.previewSize!.height,
        // );

        for (Label label in detectedObject.labels) {
          if (kDebugMode) {
            print('${label.text} ${label.confidence}');
          }
        }

        double camHeight = _cameraController.value.previewSize!.height;
        double camWidth = _cameraController.value.previewSize!.width;
        double camArea = camHeight * camWidth;
        double rectArea = rect.height * rect.width;
        if (kDebugMode) {
          print('RectArea: $rectArea');
        }
        double zoom = camArea / rectArea;
        if (kDebugMode) {
          print("zoom: $zoom");
        }
        setState(() {
          if (zoom > maxZoom) {
            zoomVal = maxZoom;
            _cameraController.setZoomLevel(maxZoom);
          } else {
            zoomVal = zoom;
            _cameraController.setZoomLevel(zoom);
          }
        });

        // if (true) {
        //
        //   // print(detectedObject);
        //   // print(
        //   //     "${rect!.left} ${rect!.top} ${rect!.right} ${rect!.bottom}");
        // }
      }
    }
  }

  void _onTap(TapDownDetails details, BoxConstraints constraints) {
    if (!_cameraController.value.isInitialized) {
      return;
    }
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    _cameraController.setExposurePoint(offset);
    _cameraController.setFocusPoint(offset);
  }

  @override
  void initState() {
    _setCamera();
    objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    objectDetector!.close();
    _cameraController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              LayoutBuilder(builder: (context, boxConstraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    _onTap(details, boxConstraints);
                  },
                  child: Center(
                    child: CameraPreview(_cameraController),
                  ),
                );
              }),
              Slider(
                value: zoomVal,
                min: 1,
                max: maxZoom,
                onChanged: (val) {
                  setState(() {
                    zoomVal = val;
                    _cameraController.setZoomLevel(zoomVal);
                  });
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if(shutterAvailable) {
            shutterAvailable = false;
            _cameraController.setFocusPoint(const Offset(0.5, 0.5));
            _cameraController.setExposurePoint(const Offset(0.5, 0.5));
            _cameraController.stopImageStream();
            final picture = await _cameraController.takePicture();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImagePreview(image: picture),
              ),
            );
            _cameraController.startImageStream((image) async {
              startImageStream(image);
            });
            shutterAvailable = true;
          }
        },
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
