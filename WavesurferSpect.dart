import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smarthear_flutter_doctor/helpers/WavFileReader.dart';
import '../../controllers/BleController.dart';
import 'dart:math';
import 'package:bitmap/bitmap.dart';

//wavesurfer频谱，flutter移植
class WavesurferSpect extends StatefulWidget {
  String path = '';
  WavesurferSpect(String path) {
    this.path = path;
  }

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return WavesurferSpectState();
  }
}

class WavesurferSpectState extends State<WavesurferSpect> {
  GlobalKey<WavesurferSpectState> _globalKey = GlobalKey();
  int width = 0, height = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // final RenderObject? renderBoxRed = _globalKey.currentContext!.size();
      // final sizeRed = renderBoxRed;
      setState(() {
        width = Get.width.toInt() - 32;
        height = _globalKey.currentContext!.size!.height.toInt();
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    String bmpPath = widget.path.replaceAll('.wav', '_spect.bmp');
    File file = File(bmpPath);
    bool exists = file.existsSync();
    print('spectrogram:$exists');
    return SizedBox(
      height: 128,
      key: _globalKey,
      child: width == 0
          ? Container()
          : (exists ? Image.file(file) : WavesurferSpectPainter(widget.path, width, height)),
    );
  }
}

class WavesurferSpectPainter extends StatelessWidget {
  int width = 0, height = 0;
  List<double> dList = [];
  List<List<int>> resampleList = [];
  int hlWidth = 0;
  String path = '';
  final List<List<double>> colorMap = [
    [0, 0, 0.5137254901960784, 1],
    [0, 0.00784313725490196, 0.5176470588235295, 1],
    [0, 0.01568627450980392, 0.5215686274509804, 1],
    [0, 0.023529411764705882, 0.5294117647058824, 1],
    [0, 0.03137254901960784, 0.5333333333333333, 1],
    [0, 0.03529411764705882, 0.5372549019607843, 1],
    [0, 0.043137254901960784, 0.5411764705882353, 1],
    [0, 0.050980392156862744, 0.5490196078431373, 1],
    [0, 0.058823529411764705, 0.5529411764705883, 1],
    [0, 0.06666666666666667, 0.5568627450980392, 1],
    [0, 0.07450980392156863, 0.5607843137254902, 1],
    [0, 0.08235294117647059, 0.5647058823529412, 1],
    [0, 0.09019607843137255, 0.5725490196078431, 1],
    [0, 0.09411764705882353, 0.5764705882352941, 1],
    [0, 0.10196078431372549, 0.5803921568627451, 1],
    [0, 0.10980392156862745, 0.5843137254901961, 1],
    [0, 0.11764705882352941, 0.592156862745098, 1],
    [0, 0.12549019607843137, 0.596078431372549, 1],
    [0, 0.13333333333333333, 0.6, 1],
    [0, 0.1411764705882353, 0.6039215686274509, 1],
    [0, 0.14901960784313725, 0.6078431372549019, 1],
    [0, 0.15294117647058825, 0.615686274509804, 1],
    [0, 0.1607843137254902, 0.6196078431372549, 1],
    [0, 0.16862745098039217, 0.6235294117647059, 1],
    [0, 0.17647058823529413, 0.6274509803921569, 1],
    [0, 0.1843137254901961, 0.6313725490196078, 1],
    [0, 0.19215686274509805, 0.6392156862745098, 1],
    [0, 0.2, 0.6431372549019608, 1],
    [0, 0.20784313725490197, 0.6470588235294118, 1],
    [0, 0.21176470588235294, 0.6509803921568628, 1],
    [0, 0.2196078431372549, 0.6588235294117647, 1],
    [0, 0.22745098039215686, 0.6627450980392157, 1],
    [0, 0.23529411764705882, 0.6666666666666666, 1],
    [0, 0.24705882352941178, 0.6705882352941176, 1],
    [0, 0.25882352941176473, 0.6784313725490196, 1],
    [0, 0.27058823529411763, 0.6823529411764706, 1],
    [0, 0.2823529411764706, 0.6862745098039216, 1],
    [0, 0.29411764705882354, 0.6941176470588235, 1],
    [0, 0.3058823529411765, 0.6980392156862745, 1],
    [0.00392156862745098, 0.3176470588235294, 0.7019607843137254, 1],
    [0.00392156862745098, 0.32941176470588235, 0.7098039215686275, 1],
    [0.00392156862745098, 0.3411764705882353, 0.7137254901960784, 1],
    [0.00392156862745098, 0.35294117647058826, 0.7176470588235294, 1],
    [0.00392156862745098, 0.3686274509803922, 0.7254901960784313, 1],
    [0.00392156862745098, 0.3803921568627451, 0.7294117647058823, 1],
    [0.00392156862745098, 0.39215686274509803, 0.7333333333333333, 1],
    [0.00392156862745098, 0.403921568627451, 0.7411764705882353, 1],
    [0.00392156862745098, 0.41568627450980394, 0.7450980392156863, 1],
    [0.00392156862745098, 0.42745098039215684, 0.7490196078431373, 1],
    [0.00392156862745098, 0.4392156862745098, 0.7568627450980392, 1],
    [0.00392156862745098, 0.45098039215686275, 0.7607843137254902, 1],
    [0.00392156862745098, 0.4627450980392157, 0.7647058823529411, 1],
    [0.00784313725490196, 0.4745098039215686, 0.7725490196078432, 1],
    [0.00784313725490196, 0.48627450980392156, 0.7764705882352941, 1],
    [0.00784313725490196, 0.4980392156862745, 0.7803921568627451, 1],
    [0.00784313725490196, 0.5098039215686274, 0.788235294117647, 1],
    [0.00784313725490196, 0.5215686274509804, 0.792156862745098, 1],
    [0.00784313725490196, 0.5333333333333333, 0.796078431372549, 1],
    [0.00784313725490196, 0.5450980392156862, 0.803921568627451, 1],
    [0.00784313725490196, 0.5568627450980392, 0.807843137254902, 1],
    [0.00784313725490196, 0.5686274509803921, 0.8117647058823529, 1],
    [0.00784313725490196, 0.5803921568627451, 0.8196078431372549, 1],
    [0.00784313725490196, 0.592156862745098, 0.8235294117647058, 1],
    [0.00784313725490196, 0.6039215686274509, 0.8274509803921568, 1],
    [0.011764705882352941, 0.6196078431372549, 0.8352941176470589, 1],
    [0.011764705882352941, 0.6313725490196078, 0.8392156862745098, 1],
    [0.011764705882352941, 0.6431372549019608, 0.8431372549019608, 1],
    [0.011764705882352941, 0.6549019607843137, 0.8470588235294118, 1],
    [0.011764705882352941, 0.6666666666666666, 0.8549019607843137, 1],
    [0.011764705882352941, 0.6784313725490196, 0.8588235294117647, 1],
    [0.011764705882352941, 0.6901960784313725, 0.8627450980392157, 1],
    [0.011764705882352941, 0.7019607843137254, 0.8705882352941177, 1],
    [0.011764705882352941, 0.7137254901960784, 0.8745098039215686, 1],
    [0.011764705882352941, 0.7254901960784313, 0.8784313725490196, 1],
    [0.011764705882352941, 0.7372549019607844, 0.8862745098039215, 1],
    [0.011764705882352941, 0.7490196078431373, 0.8901960784313725, 1],
    [0.011764705882352941, 0.7607843137254902, 0.8941176470588236, 1],
    [0.01568627450980392, 0.7725490196078432, 0.9019607843137255, 1],
    [0.01568627450980392, 0.7843137254901961, 0.9058823529411765, 1],
    [0.01568627450980392, 0.796078431372549, 0.9098039215686274, 1],
    [0.01568627450980392, 0.807843137254902, 0.9176470588235294, 1],
    [0.01568627450980392, 0.8196078431372549, 0.9215686274509803, 1],
    [0.01568627450980392, 0.8313725490196079, 0.9254901960784314, 1],
    [0.01568627450980392, 0.8431372549019608, 0.9333333333333333, 1],
    [0.01568627450980392, 0.8549019607843137, 0.9372549019607843, 1],
    [0.01568627450980392, 0.8666666666666667, 0.9411764705882353, 1],
    [0.01568627450980392, 0.8823529411764706, 0.9490196078431372, 1],
    [0.01568627450980392, 0.8941176470588236, 0.9529411764705882, 1],
    [0.01568627450980392, 0.9058823529411765, 0.9568627450980393, 1],
    [0.01568627450980392, 0.9176470588235294, 0.9647058823529412, 1],
    [0.0196078431372549, 0.9294117647058824, 0.9686274509803922, 1],
    [0.0196078431372549, 0.9411764705882353, 0.9725490196078431, 1],
    [0.0196078431372549, 0.9529411764705882, 0.9803921568627451, 1],
    [0.0196078431372549, 0.9647058823529412, 0.984313725490196, 1],
    [0.0196078431372549, 0.9764705882352941, 0.9882352941176471, 1],
    [0.0196078431372549, 0.9882352941176471, 0.996078431372549, 1],
    [0.0196078431372549, 1, 1, 1],
    [0.03529411764705882, 1, 0.984313725490196, 1],
    [0.050980392156862744, 1, 0.9686274509803922, 1],
    [0.06666666666666667, 1, 0.9529411764705882, 1],
    [0.08235294117647059, 1, 0.9372549019607843, 1],
    [0.09803921568627451, 1, 0.9215686274509803, 1],
    [0.11372549019607843, 1, 0.9058823529411765, 1],
    [0.12941176470588237, 1, 0.8901960784313725, 1],
    [0.1450980392156863, 1, 0.8745098039215686, 1],
    [0.1607843137254902, 1, 0.8588235294117647, 1],
    [0.17647058823529413, 1, 0.8431372549019608, 1],
    [0.19215686274509805, 1, 0.8235294117647058, 1],
    [0.20784313725490197, 1, 0.807843137254902, 1],
    [0.2235294117647059, 1, 0.792156862745098, 1],
    [0.23921568627450981, 1, 0.7764705882352941, 1],
    [0.2549019607843137, 1, 0.7607843137254902, 1],
    [0.26666666666666666, 1, 0.7450980392156863, 1],
    [0.2823529411764706, 1, 0.7294117647058823, 1],
    [0.2980392156862745, 1, 0.7137254901960784, 1],
    [0.3137254901960784, 1, 0.6980392156862745, 1],
    [0.32941176470588235, 1, 0.6823529411764706, 1],
    [0.34509803921568627, 1, 0.6666666666666666, 1],
    [0.3607843137254902, 1, 0.6509803921568628, 1],
    [0.3764705882352941, 1, 0.6352941176470588, 1],
    [0.39215686274509803, 1, 0.6196078431372549, 1],
    [0.40784313725490196, 1, 0.6039215686274509, 1],
    [0.4235294117647059, 1, 0.5882352941176471, 1],
    [0.4392156862745098, 1, 0.5725490196078431, 1],
    [0.4549019607843137, 1, 0.5568627450980392, 1],
    [0.47058823529411764, 1, 0.5411764705882353, 1],
    [0.48627450980392156, 1, 0.5254901960784314, 1],
    [0.5019607843137255, 1, 0.5098039215686274, 1],
    [0.5176470588235295, 1, 0.49019607843137253, 1],
    [0.5333333333333333, 1, 0.4745098039215686, 1],
    [0.5490196078431373, 1, 0.4588235294117647, 1],
    [0.5647058823529412, 1, 0.44313725490196076, 1],
    [0.5803921568627451, 1, 0.42745098039215684, 1],
    [0.596078431372549, 1, 0.4117647058823529, 1],
    [0.611764705882353, 1, 0.396078431372549, 1],
    [0.6274509803921569, 1, 0.3803921568627451, 1],
    [0.6431372549019608, 1, 0.36470588235294116, 1],
    [0.6588235294117647, 1, 0.34901960784313724, 1],
    [0.6745098039215687, 1, 0.3333333333333333, 1],
    [0.6901960784313725, 1, 0.3176470588235294, 1],
    [0.7058823529411765, 1, 0.30196078431372547, 1],
    [0.7215686274509804, 1, 0.28627450980392155, 1],
    [0.7372549019607844, 1, 0.27058823529411763, 1],
    [0.7529411764705882, 1, 0.2549019607843137, 1],
    [0.7647058823529411, 1, 0.23921568627450981, 1],
    [0.7803921568627451, 1, 0.2235294117647059, 1],
    [0.796078431372549, 1, 0.20784313725490197, 1],
    [0.8117647058823529, 1, 0.19215686274509805, 1],
    [0.8274509803921568, 1, 0.17647058823529413, 1],
    [0.8431372549019608, 1, 0.1568627450980392, 1],
    [0.8588235294117647, 1, 0.1411764705882353, 1],
    [0.8745098039215686, 1, 0.12549019607843137, 1],
    [0.8901960784313725, 1, 0.10980392156862745, 1],
    [0.9058823529411765, 1, 0.09411764705882353, 1],
    [0.9215686274509803, 1, 0.0784313725490196, 1],
    [0.9372549019607843, 1, 0.06274509803921569, 1],
    [0.9529411764705882, 1, 0.047058823529411764, 1],
    [0.9686274509803922, 1, 0.03137254901960784, 1],
    [0.984313725490196, 1, 0.01568627450980392, 1],
    [1, 1, 0, 1],
    [1, 0.984313725490196, 0, 1],
    [1, 0.9686274509803922, 0, 1],
    [1, 0.9529411764705882, 0, 1],
    [1, 0.9372549019607843, 0, 1],
    [1, 0.9215686274509803, 0, 1],
    [1, 0.9058823529411765, 0, 1],
    [0.996078431372549, 0.8901960784313725, 0, 1],
    [0.996078431372549, 0.8745098039215686, 0, 1],
    [0.996078431372549, 0.8588235294117647, 0, 1],
    [0.996078431372549, 0.8431372549019608, 0, 1],
    [0.996078431372549, 0.8274509803921568, 0, 1],
    [0.996078431372549, 0.8117647058823529, 0, 1],
    [0.996078431372549, 0.796078431372549, 0, 1],
    [0.996078431372549, 0.7803921568627451, 0, 1],
    [0.996078431372549, 0.7647058823529411, 0, 1],
    [0.996078431372549, 0.7490196078431373, 0, 1],
    [0.996078431372549, 0.7333333333333333, 0, 1],
    [0.996078431372549, 0.7176470588235294, 0, 1],
    [0.996078431372549, 0.7019607843137254, 0, 1],
    [0.9921568627450981, 0.6862745098039216, 0, 1],
    [0.9921568627450981, 0.6705882352941176, 0, 1],
    [0.9921568627450981, 0.6549019607843137, 0, 1],
    [0.9921568627450981, 0.6392156862745098, 0, 1],
    [0.9921568627450981, 0.6235294117647059, 0, 1],
    [0.9921568627450981, 0.6078431372549019, 0, 1],
    [0.9921568627450981, 0.592156862745098, 0, 1],
    [0.9921568627450981, 0.5764705882352941, 0, 1],
    [0.9921568627450981, 0.5607843137254902, 0, 1],
    [0.9921568627450981, 0.5450980392156862, 0, 1],
    [0.9921568627450981, 0.5294117647058824, 0, 1],
    [0.9921568627450981, 0.5137254901960784, 0, 1],
    [0.9921568627450981, 0.5019607843137255, 0, 1],
    [0.9882352941176471, 0.48627450980392156, 0, 1],
    [0.9882352941176471, 0.47058823529411764, 0, 1],
    [0.9882352941176471, 0.4549019607843137, 0, 1],
    [0.9882352941176471, 0.4392156862745098, 0, 1],
    [0.9882352941176471, 0.4235294117647059, 0, 1],
    [0.9882352941176471, 0.40784313725490196, 0, 1],
    [0.9882352941176471, 0.39215686274509803, 0, 1],
    [0.9882352941176471, 0.3764705882352941, 0, 1],
    [0.9882352941176471, 0.3607843137254902, 0, 1],
    [0.9882352941176471, 0.34509803921568627, 0, 1],
    [0.9882352941176471, 0.32941176470588235, 0, 1],
    [0.9882352941176471, 0.3137254901960784, 0, 1],
    [0.984313725490196, 0.2980392156862745, 0, 1],
    [0.984313725490196, 0.2823529411764706, 0, 1],
    [0.984313725490196, 0.26666666666666666, 0, 1],
    [0.984313725490196, 0.25098039215686274, 0, 1],
    [0.984313725490196, 0.23529411764705882, 0, 1],
    [0.984313725490196, 0.2196078431372549, 0, 1],
    [0.984313725490196, 0.20392156862745098, 0, 1],
    [0.984313725490196, 0.18823529411764706, 0, 1],
    [0.984313725490196, 0.17254901960784313, 0, 1],
    [0.984313725490196, 0.1568627450980392, 0, 1],
    [0.984313725490196, 0.1411764705882353, 0, 1],
    [0.984313725490196, 0.12549019607843137, 0, 1],
    [0.984313725490196, 0.10980392156862745, 0, 1],
    [0.9803921568627451, 0.09411764705882353, 0, 1],
    [0.9803921568627451, 0.0784313725490196, 0, 1],
    [0.9803921568627451, 0.06274509803921569, 0, 1],
    [0.9803921568627451, 0.047058823529411764, 0, 1],
    [0.9803921568627451, 0.03137254901960784, 0, 1],
    [0.9803921568627451, 0.01568627450980392, 0, 1],
    [0.9803921568627451, 0, 0, 1],
    [0.9647058823529412, 0, 0, 1],
    [0.9490196078431372, 0, 0, 1],
    [0.9372549019607843, 0, 0, 1],
    [0.9215686274509803, 0, 0, 1],
    [0.9058823529411765, 0, 0, 1],
    [0.8901960784313725, 0, 0, 1],
    [0.8745098039215686, 0, 0, 1],
    [0.8627450980392157, 0, 0, 1],
    [0.8470588235294118, 0, 0, 1],
    [0.8313725490196079, 0, 0, 1],
    [0.8156862745098039, 0, 0, 1],
    [0.8, 0, 0, 1],
    [0.7843137254901961, 0, 0, 1],
    [0.7725490196078432, 0, 0, 1],
    [0.7568627450980392, 0, 0, 1],
    [0.7411764705882353, 0, 0, 1],
    [0.7254901960784313, 0, 0, 1],
    [0.7098039215686275, 0, 0, 1],
    [0.6980392156862745, 0, 0, 1],
    [0.6823529411764706, 0, 0, 1],
    [0.6666666666666666, 0, 0, 1],
    [0.6509803921568628, 0, 0, 1],
    [0.6352941176470588, 0, 0, 1],
    [0.6235294117647059, 0, 0, 1],
    [0.6078431372549019, 0, 0, 1],
    [0.592156862745098, 0, 0, 1],
    [0.5764705882352941, 0, 0, 1],
    [0.5607843137254902, 0, 0, 1],
    [0.5450980392156862, 0, 0, 1],
    [0.5333333333333333, 0, 0, 1],
    [0.5176470588235295, 0, 0, 1],
    [0.5019607843137255, 0, 0, 1]
  ];
  WavesurferSpectPainter(String path, int width, int height) {
    this.width = width;
    this.height = height;
    this.path = path;
    Uint8List l = File(path).readAsBytesSync().sublist(44);
    dList = WavFileReader.getData(l);
    int standardLength =
        deviceName.value == '' ? 84700 : 84000;
    double hlPer = standardLength / (width * height);
    hlWidth = dList.length <= standardLength
        ? width * 2
        : (dList.length / hlPer / height).floor() * 2;
    print('length,width,height:${dList.length},$hlWidth,$height');
    resampleList = resample(getFrequencies());
  }

  List<List<int>> getFrequencies() {
//        var channelOne = buffer.getChannelData(0);
    int bufferLength = dList.length;
//        long sampleRate = waveFileReader.getSampleRate();
    List<List<int>> frequencies = [];

//        if (bufferLength == 0) {
//            return;
//        }

    int uniqueSamplesPerPx = (dList.length / hlWidth).ceil();
//            int uniqueSamplesPerPx = buffer.length;
    int noverlap = max(0, (512 - uniqueSamplesPerPx).round());

    FFT(512, 4000, "", 1);
//        var maxSlicesCount = Math.floor(bufferLength / (fftSamples - noverlap));
    int currentOffset = 0;

    while (currentOffset + 512 < bufferLength) {
      List<double> segment = dList.sublist(currentOffset, currentOffset + 512);
      List<double> spectrum = calculateSpectrum(segment);
      List<int> array = List.filled(256, 0);
//            var j = void 0;

      for (int j = 0; j < 256; j++) {
        double s = (log(spectrum[j]) / ln10) * 45;
        array[j] = (max(-255, s)).toInt() + 256;
      }

      frequencies.add(array);
      currentOffset += (512 - noverlap);
    }

//        callback(frequencies, this);
    return frequencies;
  }

  List<List<int>> resample(List<List<int>> oldMatrix) {
    int columnsNumber = hlWidth;
    List<List<int>> newMatrix = [];
    // print(oldMatrix.length);
    double oldPiece = 1.0 / oldMatrix.length;
    double newPiece = 1.0 / columnsNumber;
    for (int i = 0; i < columnsNumber; i++) {
      List<int> column = List.filled(oldMatrix[0].length, 0);
      for (int j = 0; j < oldMatrix.length; j++) {
        double oldStart = j * oldPiece;
        double oldEnd = oldStart + oldPiece;
        double newStart = i * newPiece;
        double newEnd = newStart + newPiece;
        double overlap = oldEnd <= newStart || newEnd <= oldStart
            ? 0
            : min(max(oldEnd, newStart), max(newEnd, oldStart)) -
                max(min(oldEnd, newStart), min(newEnd, oldStart));
//                var k = void 0;
/* eslint-disable max-depth */
        if (overlap > 0) {
          for (int k = 0; k < oldMatrix[0].length; k++) {
//                        if (column[k] == 0) {
//                            column[k] = 0;
//                        }

            column[k] += (overlap / newPiece * oldMatrix[j][k]).toInt();


          }
        }
/* eslint-enable max-depth */

      }

      List<int> intColumn = List.filled(oldMatrix[0].length, 0);
//            var m = void 0;
// List.copyRange(column, 0, intColumn, 0, oldMatrix[0].length);
      intColumn.setRange(0, oldMatrix[0].length, column, 0);
      newMatrix.add(intColumn);
    }
    return newMatrix;
  }

  int bandwidth = 0, peakBand = 0;
  double peak = 0;
  List<double> sinTable = [];
  List<double> cosTable = [];
  List<double> windowValues = [];
  List<int> reverseTable = [];
  FFT(int bufferSize, int sampleRate, String windowFunc, double alpha) {
    // this.bufferSize = bufferSize;
    // this.sampleRate = sampleRate;
    this.bandwidth = (2 / bufferSize * (sampleRate / 2)).toInt();
    this.sinTable = List.filled(bufferSize, 0);
    this.cosTable = List.filled(bufferSize, 0);
    this.windowValues = List.filled(bufferSize, 0);
    this.reverseTable = List.filled(bufferSize, 0);
    this.peakBand = 0;
    this.peak = 0;
//        var i;

    switch (windowFunc) {
      case "bartlett":
        for (int i = 0; i < bufferSize; i++) {
          windowValues[i] = 2.0 /
              (bufferSize - 1) *
              ((bufferSize - 1) / 2.0 - (i - (bufferSize - 1) / 2).abs());
        }

        break;

      case "bartlettHann":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = 0.62 -
              0.48 * (i / (bufferSize - 1.0) - 0.5).abs() -
              0.38 * cos(pi * 2 * i / (bufferSize - 1));
        }

        break;

      case "blackman":
        alpha = alpha > 0 ? alpha : 0.16;

        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = (1 - alpha) / 2 -
              0.5 * cos(pi * 2 * i / (bufferSize - 1)) +
              alpha / 2 * cos(4 * pi * i / (bufferSize - 1));
        }

        break;

      case "cosine":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = cos(pi * i / (bufferSize - 1) - pi / 2);
        }

        break;

        
        // case "gauss":
        // alpha = alpha > 0 ? alpha : 0.25;
        //
        // for (int i = 0; i < bufferSize; i++) {
        // this.windowValues[i] = pow(e, -0.5 * pow((i - (bufferSize - 1) / 2.0) / (alpha * (bufferSize - 1) / 2), 2));
        // }

        break;

      case "hamming":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] =
              0.54 - 0.46 * cos(pi * 2 * i / (bufferSize - 1));
        }

        break;

      case "hann":
      case "":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = 0.5 * (1 - cos(pi * 2 * i / (bufferSize - 1)));
        }

        break;

      case "lanczoz":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = sin(pi * (2.0 * i / (bufferSize - 1) - 1)) /
              (pi * (2.0 * i / (bufferSize - 1) - 1));
        }

        break;

      case "rectangular":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = 1;
        }

        break;

      case "triangular":
        for (int i = 0; i < bufferSize; i++) {
          this.windowValues[i] = 2.0 /
              bufferSize *
              (bufferSize / 2.0 - (i - (bufferSize - 1) / 2).abs());
        }

        break;

      default:
        throw new Exception("No such window function '" + windowFunc + "'");
    }

    int limit = 1;
    int bit = bufferSize >> 1;
//        var i;

    while (limit < bufferSize) {
      for (int i = 0; i < limit; i++) {
        this.reverseTable[i + limit] = this.reverseTable[i] + bit;
      }

      limit = limit << 1;
      bit = bit >> 1;
    }

    for (int i = 0; i < bufferSize; i++) {
      this.sinTable[i] = sin(-pi / i);
      this.cosTable[i] = cos(-pi / i);
    }
  }

  List<double> calculateSpectrum(List<double> buffer) {
    // int bufferSize = this.bufferSize;
    List<double> cosTable = this.cosTable;
    List<double> sinTable = this.sinTable;
    List<int> reverseTable = this.reverseTable;
    List<double> real = List.filled(512, 0);
    List<double> imag = List.filled(512, 0);
    double bSi = 2.0 / 512;
    double rval, ival, mag;
    List<double> spectrum = List.filled(256, 0);
    double k = (log(512) / 0.6931471805599453).floorToDouble();

    if (pow(2, k) != 512) {
      throw new Exception("Invalid buffer size, must be a power of 2.");
    }

    // if (512 != buffer.length) {
    // throw new Exception("Supplied buffer is not the same size as defined FFT. FFT Size: ' + bufferSize + ' Buffer Size: ' + buffer.length");
    // }

    int halfSize = 1;
    double phaseShiftStepReal,
        phaseShiftStepImag,
        currentPhaseShiftReal,
        currentPhaseShiftImag;
    int off;
    double tr, ti, tmpReal;

    for (int i = 0; i < 512; i++) {
      real[i] = buffer[reverseTable[i]] * this.windowValues[reverseTable[i]];
      imag[i] = 0;
    }

    while (halfSize < 512) {
      phaseShiftStepReal = cosTable[halfSize];
      phaseShiftStepImag = sinTable[halfSize];
      currentPhaseShiftReal = 1;
      currentPhaseShiftImag = 0;

      for (int fftStep = 0; fftStep < halfSize; fftStep++) {
        int i = fftStep;

        while (i < 512) {
          off = i + halfSize;
          tr = currentPhaseShiftReal * real[off] -
              currentPhaseShiftImag * imag[off];
          ti = currentPhaseShiftReal * imag[off] +
              currentPhaseShiftImag * real[off];
          real[off] = real[i] - tr;
          imag[off] = imag[i] - ti;
          real[i] += tr;
          imag[i] += ti;
          i += halfSize << 1;
        }

        tmpReal = currentPhaseShiftReal;
        currentPhaseShiftReal = tmpReal * phaseShiftStepReal -
            currentPhaseShiftImag * phaseShiftStepImag;
        currentPhaseShiftImag = tmpReal * phaseShiftStepImag +
            currentPhaseShiftImag * phaseShiftStepReal;
      }

      halfSize = halfSize << 1;
    }

    for (int i = 0; i < 256; i++) {
      rval = real[i];
      ival = imag[i];
      mag = bSi * sqrt(rval * rval + ival * ival);
      if (mag > this.peak) {
        this.peakBand = i;
        this.peak = mag;
      }

      spectrum[i] = mag;
    }

    return spectrum;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    print('paint');
    int heightFactor = 1;
    Uint8List imageData = Uint8List(hlWidth * height * 4);
    int errorCount = 0;
    for (int i = 0; i < resampleList.length; i++) {
      for (int j = 0; j < resampleList[i].length; j++) {
        List<double> colorPoint = colorMap[resampleList[i][j]];
        /* eslint-disable max-depth */

        for (int k = 0; k < heightFactor; k++) {
          int y = height - j * heightFactor;

          if (heightFactor == 2 && k == 1) {
            y--;
          }

          int redIndex = y * (hlWidth * 4) + i * 4;
          if (redIndex < hlWidth * height * 4 && redIndex >= 0) {
            // imageData[redIndex] = Color.rgb((int) (colorPoint[0] * 255), (int) (colorPoint[1] * 255), (int) (colorPoint[2] * 255));
            imageData[redIndex] = (colorPoint[0] * 255).toInt();
            imageData[redIndex + 1] = (colorPoint[1] * 255).toInt();
            imageData[redIndex + 2] = (colorPoint[2] * 255).toInt();
            // imageData[redIndex] = Color.fromARGB((colorPoint[3] * 255).toInt(), (colorPoint[0] * 255).toInt(), (colorPoint[1] * 255).toInt(), (colorPoint[2] * 255).toInt()).value;
            imageData[redIndex + 3] = 255;
          } else {
            errorCount++;
          }
        }
        /* eslint-enable max-depth */

      }
    }
    print('$errorCount, ${imageData.length}');
    Bitmap bitmap = Bitmap.fromHeadless(hlWidth, height, imageData);
    Uint8List uint8list = bitmap.buildHeaded();
    File file = File(path.replaceAll('.wav', '_spect.bmp'));
    file.writeAsBytesSync(uint8list);
    return Image.memory(
      uint8list,
      width: hlWidth.toDouble(),
      height: height.toDouble(),
    );
  }
}
