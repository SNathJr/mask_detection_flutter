import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _loading = true;
  late File _image;
  late List _output;
  late File _faceCrop;
  final picker = ImagePicker();
  bool isBusy = false;

  @override
  void initState() {
    //initS is the first function that is executed by default when this class is called
    super.initState();
    loadModel().then((value) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    //dis function disposes and clears our memory
    super.dispose();
    Tflite.close();
  }

  Uint8List imageToByteListUint8(img.Image image, int inputSize) {
    var convertedBytes = Uint8List(1 * inputSize * inputSize * 3);
    var buffer = Uint8List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel);
        buffer[pixelIndex++] = img.getGreen(pixel);
        buffer[pixelIndex++] = img.getBlue(pixel);
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  resizeAndReturnImage(File image, int width) async {
    // convert to bytes
    final bytes = await image.readAsBytes();
    // convert to Image
    img.Image src = img.decodeImage(bytes)!;
    // take crop of face and resize
    final resized = img.copyResize(src, width: width);
    // save result to temporary path
    Directory tempDir = await getTemporaryDirectory();
    // save to a file
    File file = await File('${tempDir.path}/tempfile1.png').writeAsBytes(img.encodePng(resized));
    return file;
  }

  cropAndReturnImage(File image, Face face) async {
    // convert to bytes
    final bytes = await image.readAsBytes();
    // convert to Image
    img.Image src = img.decodeImage(bytes)!;
    // take crop of face and resize
    final face_crop = img.copyResize(img.copyCrop(
        src,
        face.boundingBox.left.round(),
        face.boundingBox.top.round(),
        face.boundingBox.width.round(),
        face.boundingBox.height.round()
    ), width: 224);
    // save result to temporary path
    Directory tempDir = await getTemporaryDirectory();
    // save to a file
    File file = await File('${tempDir.path}/tempfile2.png').writeAsBytes(img.encodePng(face_crop));
    return file;
  }

  classifyImage(File image) async {
    // try to detect faces on image
    File resizedImage = await resizeAndReturnImage(image, 400);
    List<Face> faces = await detectFaces(resizedImage);
    // if faces not found return accordingly
    if (faces.length < 1) {
      setState(() {
        _output = [{"confidence": 1, "label": "ମୁହଁ ନାହିଁ"}];
        _loading = false;
      });
    } else {
      // get the largest face
      File face = await cropAndReturnImage(resizedImage, faces[0]);

      //this function runs the model on the image
      var output = await Tflite.runModelOnImage(
          path: face.path,
          imageMean: 127.5,
          imageStd: 127.5,
          numResults: 2,
          threshold: 0.1,
          asynch: true
      );
      print("=> results: ${output}");

      setState(() {
        _output = output!;
        _loading = false;
      });
    }
  }

  loadModel() async {
    //this function loads our model
    await Tflite.loadModel(
        model: 'assets/model_unquant.tflite', labels: 'assets/labels.txt');
  }

  pickImage() async {
    //this function to grab the image from camera
    var image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;

    setState(() {
      _image = File(image.path);
      _output = [{"confidence": 1, "label": "ଚିହ୍ନଟ ଚାଲିଛି ..."}];
    });
    classifyImage(_image);
  }

  pickGalleryImage() async {
    //this function to grab the image from gallery
    var image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    setState(() {
      _image = File(image.path);
      _output = [{"confidence": 1, "label": "ଚିହ୍ନଟ ଚାଲିଛି ..."}];
    });
    classifyImage(_image);
  }

  detectFaces(File image) async {
    InputImage input_image = InputImage.fromFile(image);
    FaceDetector faceDetector =
    GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ));
    final faces = await faceDetector.processImage(input_image);
    print('Found ${faces.length} faces');
    return faces;
    // if (mounted) {
    //   setState(() {
    //     _faces = faces;
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF184E77),
        title: Text(
          'ମାସ୍କ ପିନ୍ଧିଛନ୍ତି କି ନାହିଁ ଜାଣିବା ପାଇଁ ଏକ ଫଟୋ ଚୟନ କରନ୍ତୁ',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w200,
              fontSize: 15,
              letterSpacing: 0.8),
        ),
      ),
      body: Container(
        color: Color(0xFF1A759f),
        padding: EdgeInsets.symmetric(horizontal: 35, vertical: 40),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Color(0xFF184E77),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                child: Center(
                  child: _loading == true
                      ? null //show nothing if no picture selected
                      : Container(
                    child: Column(
                      children: [
                        Container(
                          height: 200,
                          width: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.file(
                              _image,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        Divider(
                          height: 10,
                          thickness: 1,
                        ),
                        _output != null
                            ? Text(
                          '${_output[0]['confidence'] > 0.70 ? _output[0]['label'] : "ଚିହ୍ନଟ ହେଲା ନାହିଁ"}',
                          style: TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 25,
                              fontWeight: FontWeight.w800),
                        )
                            : Container(),
                        Divider(
                          height: 10,
                          thickness: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 200,
                        alignment: Alignment.center,
                        padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 17),
                        decoration: BoxDecoration(
                            color: Color(0xFF1A759F),
                            borderRadius: BorderRadius.circular(15)),
                        child: Text(
                          'କ୍ୟାମେରା',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    GestureDetector(
                      onTap: pickGalleryImage,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 200,
                        alignment: Alignment.center,
                        padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 17),
                        decoration: BoxDecoration(
                            color: Color(0xFF1A759F),
                            borderRadius: BorderRadius.circular(15)),
                        child: Text(
                          'ଫଟୋ ଗ୍ୟାଲେରୀ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}