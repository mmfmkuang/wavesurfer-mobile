
//读取wav文件特定数据工具类

import 'dart:io';
import 'dart:typed_data';

class WavFileReader
{
  static List<double> getData(Uint8List l)
  {
    ByteBuffer buffer =
        l.buffer;
    Int16List list = buffer.asInt16List();
    List<double> doubleList = List.filled(list.length, 0);
    for (int i = 0; i < list.length; i++) {
      int vol = BigInt.from(list[i]).toSigned(16).toInt();
      if (vol > 32767) {
        vol = 32767;
      } else if (vol < -32768) {
        vol = -32768;
      }
      // list[i] = vol;
      doubleList[i] = list[i] / 32768;
    }
    return doubleList;
  }
}