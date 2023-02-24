
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../controllers/BleController.dart';
import '../../helpers/WavFileReader.dart';

//wavesurfer波型，flutter移植
class WavesurferWaveform extends StatefulWidget
{
  String path = '', color = '';
  bool isECG = false;
  WavesurferWaveform(String path, String color, bool isECG)
  {
    this.path = path;
    this.color = color;
    this.isECG = isECG;
  }

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return WavesurferWaveformState();
  }
}

class WavesurferWaveformState extends State<WavesurferWaveform>
{

  GlobalKey<WavesurferWaveformState> _globalKey = GlobalKey();
  int width = 0, height = 0;
  int hlWidth = 0;
  BleController bleController = Get.find();
  List<double> dList = [];
  // bool pngExists = false;
  String pngPath = '';
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // final RenderObject? renderBoxRed = _globalKey.currentContext!.size();
      // final sizeRed = renderBoxRed;
      width = Get.width.toInt() - 32;
      height = _globalKey.currentContext!.size!.height.toInt();
      pngPath = widget.path.replaceAll('.wav', '.png');
      if (File(pngPath).existsSync())
        {
          // pngExists = true;
          print('waveform:${widget.path}, png exists');
        }
      else
      {
        print('waveform:${widget.path}, png not exists');
        // pngExists = false;
        Uint8List l = File(widget.path).readAsBytesSync().sublist(44);
        dList = WavFileReader.getData(l);
        int standardLength = widget.isECG ? 21000 : (bleController.deviceName.value == '' ? 84700 : 84000);
        double hlPer = standardLength / (width * height);
        hlWidth = dList.length <= standardLength ? width * 2 : (dList.length / hlPer / height).floor() * 2;
        print('length,width,height:${dList.length},$hlWidth,$height');
        ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas canvas = Canvas(recorder);
        var painter = WavesurferWaveformPainter(dList, hlWidth, height, widget.isECG);
        painter.paint(canvas, Size(hlWidth.toDouble(), height.toDouble()));
        ui.Image renderedImage = await recorder
            .endRecording()
            .toImage(hlWidth, height);

        var pngBytes =
            await renderedImage.toByteData(format: ui.ImageByteFormat.png);

        File saveFile = File(pngPath);

        // if (!saveFile.existsSync()) {
        //   saveFile.createSync(recursive: true);
        // }
        saveFile.writeAsBytesSync(pngBytes!.buffer.asUint8List());
      }
      setState(()
      {
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SizedBox(
      height: 128,
      key: _globalKey,
      child: width == 0 ? Container() : Image.file(File(pngPath)),
    );
  }
}

class WavesurferWaveformPainter extends CustomPainter
{
  int width = 0, height = 0;
  List<double> peaks = [];
  bool b = false;
  WavesurferWaveformPainter(List<double> list, int width, int height, bool b)
  {
    this.width = width;
    this.height = height;
    this.b = b;
    getPeaks(list);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    if (!b) {
      drawLineToContext(canvas);
    }
    else
      {
        drawLineToContextEcg(canvas);
      }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }

  getPeaks(List<double> list) {
    // if (buffer == null || peaks != null)
    // {
    //   return;
    // }
    int first = 0;
    int last = width - 1;

    double sampleSize = list.length / width;
    int sampleStep = (sampleSize / 10).floor();//(int)Math.floor等于js的"~~"
    int channels = 1;
    for (int c = 0; c < channels; c++) {
      peaks = List.filled(2 * width, 0);
//            var chan = this.buffer.getChannelData(c);

      for (int i = first; i <= last; i++) {
        int start = (i * sampleSize).floor();
        int end = (start + sampleSize).floor();
        /**
         * Initialize the max and min to the first sample of this
         * subrange, so that even if the samples are entirely
         * on one side of zero, we still return the true max and
         * min values in the subrange.
         */

        double min = list[start];
        double max = min;

        for (int j = start; j < end; j += sampleStep) {
          double value = list[j];

          if (value > max) {
            max = value;
          }

          if (value < min) {
            min = value;
          }
        }

        peaks[2 * i] = max;
        peaks[2 * i + 1] = min;

//                if (max > peaks[2 * i]) {
//                    peaks[2 * i] = max;
//                }
//
//                if (min < peaks[2 * i + 1]) {
//                    peaks[2 * i + 1] = min;
//                }
      }
    }

//        return this.params.splitChannels ? this.splitPeaks : this.mergedPeaks;
  }

  drawLineToContext(Canvas canvas) {
//        var first = Math.round(length * this.start); // use one more peak value to make sure we join peaks at ends -- unless,
    // of course, this is the last canvas
    // if (peaks == null || peaks.length == 0)
    // {
    //   return;
    // }
    int last = (peaks.length / 2).round() + 1;
    int canvasStart = 0;
    double scale = 0.999253731343284; // optimization
    double halfOffset = height / 2;
    double absmaxHalf = (1 / 3) / (height / 2);
    Path path = new Path();
    path.moveTo((canvasStart * scale), halfOffset.toDouble());
    path.lineTo((canvasStart * scale), halfOffset - peaks[2 * canvasStart] / absmaxHalf);

    for (int i = 0; i < last; i++) {
      double peak = 2 * i < peaks.length ? peaks[2 * i] : 0;
      int h = (peak / absmaxHalf).round();
      path.lineTo((i * scale), halfOffset - h);
    } // draw the bottom edge going backwards, to make a single
    // closed hull to fill


    for (int j = last - 1; j >= canvasStart; j--) {
      double peak = 2 * j + 1 < peaks.length ? peaks[2 * j + 1] : 0;
      int h = (peak / absmaxHalf).round();
      path.lineTo((j * scale), halfOffset - h);
    }

    path.lineTo((canvasStart * scale), halfOffset - ((peaks[1]) / absmaxHalf).round());
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  drawLineToContextEcg(Canvas canvas) {
//        var first = Math.round(length * this.start); // use one more peak value to make sure we join peaks at ends -- unless,
    // of course, this is the last canvas
    // if (peaks == null || peaks.length == 0)
    // {
    //   return;
    // }
    int last = (peaks.length / 2).round() + 1;
    int canvasStart = 0;
    double scale = 0.999253731343284; // optimization
    double halfOffset = height / 2;
    double absmaxHalf = (1 / 3) / (height / 2);
    // Path path = new Path();
    Paint paint = Paint()..color = Colors.redAccent;
    canvas.drawLine(Offset((canvasStart * scale), halfOffset.toDouble()),
        Offset((canvasStart * scale), halfOffset - peaks[2 * canvasStart] / absmaxHalf), paint);
    double lastX = (canvasStart * scale);
    double lastY = halfOffset - peaks[2 * canvasStart] / absmaxHalf;
    for (int i = 0; i < last; i++) {
      double peak = 2 * i < peaks.length ? peaks[2 * i] : 0;
      int h = (peak / absmaxHalf).round();
      canvas.drawLine(Offset(lastX, lastY), Offset((i * scale), halfOffset - h), paint);
      lastX = (i * scale);
      lastY = halfOffset - h;
    } // draw the bottom edge going backwards, to make a single
    // closed hull to fill


    // for (int j = last - 1; j >= canvasStart; j--) {
    //   double peak = 2 * j + 1 < peaks.length ? peaks[2 * j + 1] : 0;
    //   int h = (peak / absmaxHalf).round();
    //   canvas.drawLine(Offset(lastX, lastY), Offset((j * scale), halfOffset - h), paint);
    //   lastX = (j * scale);
    //   lastY = halfOffset - h;
    // }

    // canvas.drawLine(Offset(lastX, lastY), Offset((canvasStart * scale), halfOffset - ((peaks[1]) / absmaxHalf).round()), paint);
    // path.close();
    // canvas.drawPath(path, Paint()..color = Color(0xff4AAAFF));
  }
}
