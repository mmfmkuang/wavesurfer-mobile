
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.Nullable;

import java.io.File;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

//wavesurfer.js 频谱移植
public class WavesurferSpect extends View {

    int bufferSize, sampleRate, bandwidth, peakBand;
    int noverlap = 0;
    double[] sinTable, cosTable, windowValues;
    int[] reverseTable;
    double peak;
//    String inputFile = "";

    public WavesurferSpect(Context context) {
        super(context);
    }

    public WavesurferSpect(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (buffer != null)
        {
            try {
                canvas.drawBitmap(drawSpectrogram(getFrequencies()), 60, 0, paint);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        else
        {
            if (!cachePath.isEmpty())
            {
                canvas.drawBitmap(BitmapFactory.decodeFile(cachePath, new BitmapFactory.Options()), 60, 0, paint);
            }
        }

        paint.setTextSize(10);
        for (int i=0; i<=2000; i+=400) {
            int height = (int)((getHeight() - 15) * (((2000f - i) / 2000f))) + 10;
            canvas.drawText((i / 1000f) + "kHz", 8, height, paint);
        }
    }



    void FFT(int bufferSize, int sampleRate, String windowFunc, double alpha) throws Exception {
        this.bufferSize = bufferSize;
        this.sampleRate = sampleRate;
        this.bandwidth = 2 / bufferSize * (sampleRate / 2);
        this.sinTable = new double[bufferSize];
        this.cosTable = new double[bufferSize];
        this.windowValues = new double[bufferSize];
        this.reverseTable = new int[bufferSize];
        this.peakBand = 0;
        this.peak = 0;
//        var i;

        switch (windowFunc) {
            case "bartlett":
                for (int i = 0; i < bufferSize; i++) {
                    windowValues[i] = 2.0 / (bufferSize - 1) * ((bufferSize - 1) / 2.0 - Math.abs(i - (bufferSize - 1) / 2));
                }

                break;

            case "bartlettHann":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = 0.62 - 0.48 * Math.abs(i / (bufferSize - 1.0) - 0.5) - 0.38 * Math.cos(Math.PI * 2 * i / (bufferSize - 1));
                }

                break;

            case "blackman":
                alpha = alpha > 0 ? alpha : 0.16;

                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = (1 - alpha) / 2 - 0.5 * Math.cos(Math.PI * 2 * i / (bufferSize - 1)) + alpha / 2 * Math.cos(4 * Math.PI * i / (bufferSize - 1));
                }

                break;

            case "cosine":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = Math.cos(Math.PI * i / (bufferSize - 1) - Math.PI / 2);
                }

                break;

            case "gauss":
                alpha = alpha > 0 ? alpha : 0.25;

                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = Math.pow(Math.E, -0.5 * Math.pow((i - (bufferSize - 1) / 2.0) / (alpha * (bufferSize - 1) / 2), 2));
                }

                break;

            case "hamming":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = 0.54 - 0.46 * Math.cos(Math.PI * 2 * i / (bufferSize - 1));
                }

                break;

            case "hann":
            case "":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = 0.5 * (1 - Math.cos(Math.PI * 2 * i / (bufferSize - 1)));
                }

                break;

            case "lanczoz":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = Math.sin(Math.PI * (2.0 * i / (bufferSize - 1) - 1)) / (Math.PI * (2.0 * i / (bufferSize - 1) - 1));
                }

                break;

            case "rectangular":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = 1;
                }

                break;

            case "triangular":
                for (int i = 0; i < bufferSize; i++) {
                    this.windowValues[i] = 2.0 / bufferSize * (bufferSize / 2.0 - Math.abs(i - (bufferSize - 1) / 2));
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
            this.sinTable[i] = Math.sin(-Math.PI / i);
            this.cosTable[i] = Math.cos(-Math.PI / i);
        }
    }

    double[] calculateSpectrum(double[] buffer) throws Exception {
        int bufferSize = this.bufferSize;
        double[] cosTable = this.cosTable;
        double[] sinTable = this.sinTable;
        int[] reverseTable = this.reverseTable;
        double[] real = new double[bufferSize];
        double[] imag = new double[bufferSize];
        double bSi = 2.0 / this.bufferSize;
        double rval, ival, mag;
        double[] spectrum = new double[bufferSize / 2];
        double k = Math.floor(Math.log(bufferSize) / 0.6931471805599453);

        if (Math.pow(2, k) != bufferSize) {
            throw new Exception("Invalid buffer size, must be a power of 2.");
        }

        if (bufferSize != buffer.length) {
            throw new Exception("Supplied buffer is not the same size as defined FFT. FFT Size: ' + bufferSize + ' Buffer Size: ' + buffer.length");
        }

        int halfSize = 1;
                double phaseShiftStepReal,
                phaseShiftStepImag,
                currentPhaseShiftReal,
                currentPhaseShiftImag;
                int off;
                double tr,
                ti,
                tmpReal;

        for (int i = 0; i < bufferSize; i++) {
            real[i] = buffer[reverseTable[i]] * this.windowValues[reverseTable[i]];
            imag[i] = 0;
        }

        while (halfSize < bufferSize) {
            phaseShiftStepReal = cosTable[halfSize];
            phaseShiftStepImag = sinTable[halfSize];
            currentPhaseShiftReal = 1;
            currentPhaseShiftImag = 0;

            for (int fftStep = 0; fftStep < halfSize; fftStep++) {
                int i = fftStep;

                while (i < bufferSize) {
                    off = i + halfSize;
                    tr = currentPhaseShiftReal * real[off] - currentPhaseShiftImag * imag[off];
                    ti = currentPhaseShiftReal * imag[off] + currentPhaseShiftImag * real[off];
                    real[off] = real[i] - tr;
                    imag[off] = imag[i] - ti;
                    real[i] += tr;
                    imag[i] += ti;
                    i += halfSize << 1;
                }

                tmpReal = currentPhaseShiftReal;
                currentPhaseShiftReal = tmpReal * phaseShiftStepReal - currentPhaseShiftImag * phaseShiftStepImag;
                currentPhaseShiftImag = tmpReal * phaseShiftStepImag + currentPhaseShiftImag * phaseShiftStepReal;
            }

            halfSize = halfSize << 1;
        }

        for (int i = 0; i < bufferSize / 2; i++) {
            rval = real[i];
            ival = imag[i];
            mag = bSi * Math.sqrt(rval * rval + ival * ival);
            if (mag > this.peak) {
                this.peakBand = i;
                this.peak = mag;
            }

            spectrum[i] = mag;
        }

        return spectrum;
    }

    int fftSamples = 512;
    double[] buffer;
//    long sampleRate = 4000;
    public void setData(double[] buffer, int sampleRate, String savePath)
    {
        this.buffer = buffer;
        this.sampleRate = sampleRate;
        this.cachePath = savePath;
        invalidate();
    }

    String cachePath = "";
    public void setData(String path)
    {
        this.cachePath = path;
        invalidate();
    }

    int[][] getFrequencies() throws Exception {
        int fftSamples = this.fftSamples;
//        var channelOne = buffer.getChannelData(0);
        int bufferLength = buffer.length;
//        long sampleRate = waveFileReader.getSampleRate();
        List<int[]> frequencies = new ArrayList<>();

//        if (bufferLength == 0) {
//            return;
//        }

        int noverlap = this.noverlap;

        if (noverlap == 0) {
            int uniqueSamplesPerPx = buffer.length / (getWidth() - 60);
//            int uniqueSamplesPerPx = buffer.length;
            noverlap = Math.max(0, Math.round(fftSamples - uniqueSamplesPerPx));
        }

        FFT(fftSamples, (int)sampleRate, "", 1);
//        var maxSlicesCount = Math.floor(bufferLength / (fftSamples - noverlap));
        int currentOffset = 0;

        while (currentOffset + fftSamples < bufferLength) {
            double[] segment = Arrays.copyOfRange(buffer, currentOffset, currentOffset + fftSamples);
            double[] spectrum = calculateSpectrum(segment);
            int[] array = new int[fftSamples / 2];
//            var j = void 0;

            for (int j = 0; j < fftSamples / 2; j++) {
                double s = Math.log10(spectrum[j]) * 45;
                array[j] = (int) (Math.max(-255, s)) + 256;
            }

            frequencies.add(array);
            currentOffset += fftSamples - noverlap;
        }

//        callback(frequencies, this);
        return frequencies.toArray(new int[][]{});
    }

    int[][] resample(int[][] oldMatrix) {
        int columnsNumber = getWidth() - 60;
//        int columnsNumber = 1080;
        List<int[]> newMatrix = new ArrayList<>();
        double oldPiece = 1.0 / oldMatrix.length;
        double newPiece = 1.0 / columnsNumber;
//        var i;

        for (int i = 0; i < columnsNumber; i++) {
            int[] column = new int[oldMatrix[0].length];
//            var j = void 0;
            for (int j = 0; j < oldMatrix.length; j++) {
                double oldStart = j * oldPiece;
                double oldEnd = oldStart + oldPiece;
                double newStart = i * newPiece;
                double newEnd = newStart + newPiece;
                double overlap = oldEnd <= newStart || newEnd <= oldStart ? 0 : Math.min(Math.max(oldEnd, newStart), Math.max(newEnd, oldStart)) - Math.max(Math.min(oldEnd, newStart), Math.min(newEnd, oldStart));
//                var k = void 0;
                /* eslint-disable max-depth */
                if (overlap > 0) {
                    for (int k = 0; k < oldMatrix[0].length; k++) {
//                        if (column[k] == 0) {
//                            column[k] = 0;
//                        }
                          column[k] += overlap / newPiece * oldMatrix[j][k];


                    }
                }
                /* eslint-enable max-depth */

            }

            int[] intColumn = new int[oldMatrix[0].length];
//            var m = void 0;

            System.arraycopy(column, 0, intColumn, 0, oldMatrix[0].length);

            newMatrix.add(intColumn);
        }

        return newMatrix.toArray(new int[][]{});
    }

    private Paint paint = new Paint();
    double[][] colorMap = {{0,0,0.5137254901960784,1},{0,0.00784313725490196,0.5176470588235295,1},{0,0.01568627450980392,0.5215686274509804,1},{0,0.023529411764705882,0.5294117647058824,1},{0,0.03137254901960784,0.5333333333333333,1},{0,0.03529411764705882,0.5372549019607843,1},{0,0.043137254901960784,0.5411764705882353,1},{0,0.050980392156862744,0.5490196078431373,1},{0,0.058823529411764705,0.5529411764705883,1},{0,0.06666666666666667,0.5568627450980392,1},{0,0.07450980392156863,0.5607843137254902,1},{0,0.08235294117647059,0.5647058823529412,1},{0,0.09019607843137255,0.5725490196078431,1},{0,0.09411764705882353,0.5764705882352941,1},{0,0.10196078431372549,0.5803921568627451,1},{0,0.10980392156862745,0.5843137254901961,1},{0,0.11764705882352941,0.592156862745098,1},{0,0.12549019607843137,0.596078431372549,1},{0,0.13333333333333333,0.6,1},{0,0.1411764705882353,0.6039215686274509,1},{0,0.14901960784313725,0.6078431372549019,1},{0,0.15294117647058825,0.615686274509804,1},{0,0.1607843137254902,0.6196078431372549,1},{0,0.16862745098039217,0.6235294117647059,1},{0,0.17647058823529413,0.6274509803921569,1},{0,0.1843137254901961,0.6313725490196078,1},{0,0.19215686274509805,0.6392156862745098,1},{0,0.2,0.6431372549019608,1},{0,0.20784313725490197,0.6470588235294118,1},{0,0.21176470588235294,0.6509803921568628,1},{0,0.2196078431372549,0.6588235294117647,1},{0,0.22745098039215686,0.6627450980392157,1},{0,0.23529411764705882,0.6666666666666666,1},{0,0.24705882352941178,0.6705882352941176,1},{0,0.25882352941176473,0.6784313725490196,1},{0,0.27058823529411763,0.6823529411764706,1},{0,0.2823529411764706,0.6862745098039216,1},{0,0.29411764705882354,0.6941176470588235,1},{0,0.3058823529411765,0.6980392156862745,1},{0.00392156862745098,0.3176470588235294,0.7019607843137254,1},{0.00392156862745098,0.32941176470588235,0.7098039215686275,1},{0.00392156862745098,0.3411764705882353,0.7137254901960784,1},{0.00392156862745098,0.35294117647058826,0.7176470588235294,1},{0.00392156862745098,0.3686274509803922,0.7254901960784313,1},{0.00392156862745098,0.3803921568627451,0.7294117647058823,1},{0.00392156862745098,0.39215686274509803,0.7333333333333333,1},{0.00392156862745098,0.403921568627451,0.7411764705882353,1},{0.00392156862745098,0.41568627450980394,0.7450980392156863,1},{0.00392156862745098,0.42745098039215684,0.7490196078431373,1},{0.00392156862745098,0.4392156862745098,0.7568627450980392,1},{0.00392156862745098,0.45098039215686275,0.7607843137254902,1},{0.00392156862745098,0.4627450980392157,0.7647058823529411,1},{0.00784313725490196,0.4745098039215686,0.7725490196078432,1},{0.00784313725490196,0.48627450980392156,0.7764705882352941,1},{0.00784313725490196,0.4980392156862745,0.7803921568627451,1},{0.00784313725490196,0.5098039215686274,0.788235294117647,1},{0.00784313725490196,0.5215686274509804,0.792156862745098,1},{0.00784313725490196,0.5333333333333333,0.796078431372549,1},{0.00784313725490196,0.5450980392156862,0.803921568627451,1},{0.00784313725490196,0.5568627450980392,0.807843137254902,1},{0.00784313725490196,0.5686274509803921,0.8117647058823529,1},{0.00784313725490196,0.5803921568627451,0.8196078431372549,1},{0.00784313725490196,0.592156862745098,0.8235294117647058,1},{0.00784313725490196,0.6039215686274509,0.8274509803921568,1},{0.011764705882352941,0.6196078431372549,0.8352941176470589,1},{0.011764705882352941,0.6313725490196078,0.8392156862745098,1},{0.011764705882352941,0.6431372549019608,0.8431372549019608,1},{0.011764705882352941,0.6549019607843137,0.8470588235294118,1},{0.011764705882352941,0.6666666666666666,0.8549019607843137,1},{0.011764705882352941,0.6784313725490196,0.8588235294117647,1},{0.011764705882352941,0.6901960784313725,0.8627450980392157,1},{0.011764705882352941,0.7019607843137254,0.8705882352941177,1},{0.011764705882352941,0.7137254901960784,0.8745098039215686,1},{0.011764705882352941,0.7254901960784313,0.8784313725490196,1},{0.011764705882352941,0.7372549019607844,0.8862745098039215,1},{0.011764705882352941,0.7490196078431373,0.8901960784313725,1},{0.011764705882352941,0.7607843137254902,0.8941176470588236,1},{0.01568627450980392,0.7725490196078432,0.9019607843137255,1},{0.01568627450980392,0.7843137254901961,0.9058823529411765,1},{0.01568627450980392,0.796078431372549,0.9098039215686274,1},{0.01568627450980392,0.807843137254902,0.9176470588235294,1},{0.01568627450980392,0.8196078431372549,0.9215686274509803,1},{0.01568627450980392,0.8313725490196079,0.9254901960784314,1},{0.01568627450980392,0.8431372549019608,0.9333333333333333,1},{0.01568627450980392,0.8549019607843137,0.9372549019607843,1},{0.01568627450980392,0.8666666666666667,0.9411764705882353,1},{0.01568627450980392,0.8823529411764706,0.9490196078431372,1},{0.01568627450980392,0.8941176470588236,0.9529411764705882,1},{0.01568627450980392,0.9058823529411765,0.9568627450980393,1},{0.01568627450980392,0.9176470588235294,0.9647058823529412,1},{0.0196078431372549,0.9294117647058824,0.9686274509803922,1},{0.0196078431372549,0.9411764705882353,0.9725490196078431,1},{0.0196078431372549,0.9529411764705882,0.9803921568627451,1},{0.0196078431372549,0.9647058823529412,0.984313725490196,1},{0.0196078431372549,0.9764705882352941,0.9882352941176471,1},{0.0196078431372549,0.9882352941176471,0.996078431372549,1},{0.0196078431372549,1,1,1},{0.03529411764705882,1,0.984313725490196,1},{0.050980392156862744,1,0.9686274509803922,1},{0.06666666666666667,1,0.9529411764705882,1},{0.08235294117647059,1,0.9372549019607843,1},{0.09803921568627451,1,0.9215686274509803,1},{0.11372549019607843,1,0.9058823529411765,1},{0.12941176470588237,1,0.8901960784313725,1},{0.1450980392156863,1,0.8745098039215686,1},{0.1607843137254902,1,0.8588235294117647,1},{0.17647058823529413,1,0.8431372549019608,1},{0.19215686274509805,1,0.8235294117647058,1},{0.20784313725490197,1,0.807843137254902,1},{0.2235294117647059,1,0.792156862745098,1},{0.23921568627450981,1,0.7764705882352941,1},{0.2549019607843137,1,0.7607843137254902,1},{0.26666666666666666,1,0.7450980392156863,1},{0.2823529411764706,1,0.7294117647058823,1},{0.2980392156862745,1,0.7137254901960784,1},{0.3137254901960784,1,0.6980392156862745,1},{0.32941176470588235,1,0.6823529411764706,1},{0.34509803921568627,1,0.6666666666666666,1},{0.3607843137254902,1,0.6509803921568628,1},{0.3764705882352941,1,0.6352941176470588,1},{0.39215686274509803,1,0.6196078431372549,1},{0.40784313725490196,1,0.6039215686274509,1},{0.4235294117647059,1,0.5882352941176471,1},{0.4392156862745098,1,0.5725490196078431,1},{0.4549019607843137,1,0.5568627450980392,1},{0.47058823529411764,1,0.5411764705882353,1},{0.48627450980392156,1,0.5254901960784314,1},{0.5019607843137255,1,0.5098039215686274,1},{0.5176470588235295,1,0.49019607843137253,1},{0.5333333333333333,1,0.4745098039215686,1},{0.5490196078431373,1,0.4588235294117647,1},{0.5647058823529412,1,0.44313725490196076,1},{0.5803921568627451,1,0.42745098039215684,1},{0.596078431372549,1,0.4117647058823529,1},{0.611764705882353,1,0.396078431372549,1},{0.6274509803921569,1,0.3803921568627451,1},{0.6431372549019608,1,0.36470588235294116,1},{0.6588235294117647,1,0.34901960784313724,1},{0.6745098039215687,1,0.3333333333333333,1},{0.6901960784313725,1,0.3176470588235294,1},{0.7058823529411765,1,0.30196078431372547,1},{0.7215686274509804,1,0.28627450980392155,1},{0.7372549019607844,1,0.27058823529411763,1},{0.7529411764705882,1,0.2549019607843137,1},{0.7647058823529411,1,0.23921568627450981,1},{0.7803921568627451,1,0.2235294117647059,1},{0.796078431372549,1,0.20784313725490197,1},{0.8117647058823529,1,0.19215686274509805,1},{0.8274509803921568,1,0.17647058823529413,1},{0.8431372549019608,1,0.1568627450980392,1},{0.8588235294117647,1,0.1411764705882353,1},{0.8745098039215686,1,0.12549019607843137,1},{0.8901960784313725,1,0.10980392156862745,1},{0.9058823529411765,1,0.09411764705882353,1},{0.9215686274509803,1,0.0784313725490196,1},{0.9372549019607843,1,0.06274509803921569,1},{0.9529411764705882,1,0.047058823529411764,1},{0.9686274509803922,1,0.03137254901960784,1},{0.984313725490196,1,0.01568627450980392,1},{1,1,0,1},{1,0.984313725490196,0,1},{1,0.9686274509803922,0,1},{1,0.9529411764705882,0,1},{1,0.9372549019607843,0,1},{1,0.9215686274509803,0,1},{1,0.9058823529411765,0,1},{0.996078431372549,0.8901960784313725,0,1},{0.996078431372549,0.8745098039215686,0,1},{0.996078431372549,0.8588235294117647,0,1},{0.996078431372549,0.8431372549019608,0,1},{0.996078431372549,0.8274509803921568,0,1},{0.996078431372549,0.8117647058823529,0,1},{0.996078431372549,0.796078431372549,0,1},{0.996078431372549,0.7803921568627451,0,1},{0.996078431372549,0.7647058823529411,0,1},{0.996078431372549,0.7490196078431373,0,1},{0.996078431372549,0.7333333333333333,0,1},{0.996078431372549,0.7176470588235294,0,1},{0.996078431372549,0.7019607843137254,0,1},{0.9921568627450981,0.6862745098039216,0,1},{0.9921568627450981,0.6705882352941176,0,1},{0.9921568627450981,0.6549019607843137,0,1},{0.9921568627450981,0.6392156862745098,0,1},{0.9921568627450981,0.6235294117647059,0,1},{0.9921568627450981,0.6078431372549019,0,1},{0.9921568627450981,0.592156862745098,0,1},{0.9921568627450981,0.5764705882352941,0,1},{0.9921568627450981,0.5607843137254902,0,1},{0.9921568627450981,0.5450980392156862,0,1},{0.9921568627450981,0.5294117647058824,0,1},{0.9921568627450981,0.5137254901960784,0,1},{0.9921568627450981,0.5019607843137255,0,1},{0.9882352941176471,0.48627450980392156,0,1},{0.9882352941176471,0.47058823529411764,0,1},{0.9882352941176471,0.4549019607843137,0,1},{0.9882352941176471,0.4392156862745098,0,1},{0.9882352941176471,0.4235294117647059,0,1},{0.9882352941176471,0.40784313725490196,0,1},{0.9882352941176471,0.39215686274509803,0,1},{0.9882352941176471,0.3764705882352941,0,1},{0.9882352941176471,0.3607843137254902,0,1},{0.9882352941176471,0.34509803921568627,0,1},{0.9882352941176471,0.32941176470588235,0,1},{0.9882352941176471,0.3137254901960784,0,1},{0.984313725490196,0.2980392156862745,0,1},{0.984313725490196,0.2823529411764706,0,1},{0.984313725490196,0.26666666666666666,0,1},{0.984313725490196,0.25098039215686274,0,1},{0.984313725490196,0.23529411764705882,0,1},{0.984313725490196,0.2196078431372549,0,1},{0.984313725490196,0.20392156862745098,0,1},{0.984313725490196,0.18823529411764706,0,1},{0.984313725490196,0.17254901960784313,0,1},{0.984313725490196,0.1568627450980392,0,1},{0.984313725490196,0.1411764705882353,0,1},{0.984313725490196,0.12549019607843137,0,1},{0.984313725490196,0.10980392156862745,0,1},{0.9803921568627451,0.09411764705882353,0,1},{0.9803921568627451,0.0784313725490196,0,1},{0.9803921568627451,0.06274509803921569,0,1},{0.9803921568627451,0.047058823529411764,0,1},{0.9803921568627451,0.03137254901960784,0,1},{0.9803921568627451,0.01568627450980392,0,1},{0.9803921568627451,0,0,1},{0.9647058823529412,0,0,1},{0.9490196078431372,0,0,1},{0.9372549019607843,0,0,1},{0.9215686274509803,0,0,1},{0.9058823529411765,0,0,1},{0.8901960784313725,0,0,1},{0.8745098039215686,0,0,1},{0.8627450980392157,0,0,1},{0.8470588235294118,0,0,1},{0.8313725490196079,0,0,1},{0.8156862745098039,0,0,1},{0.8,0,0,1},{0.7843137254901961,0,0,1},{0.7725490196078432,0,0,1},{0.7568627450980392,0,0,1},{0.7411764705882353,0,0,1},{0.7254901960784313,0,0,1},{0.7098039215686275,0,0,1},{0.6980392156862745,0,0,1},{0.6823529411764706,0,0,1},{0.6666666666666666,0,0,1},{0.6509803921568628,0,0,1},{0.6352941176470588,0,0,1},{0.6235294117647059,0,0,1},{0.6078431372549019,0,0,1},{0.592156862745098,0,0,1},{0.5764705882352941,0,0,1},{0.5607843137254902,0,0,1},{0.5450980392156862,0,0,1},{0.5333333333333333,0,0,1},{0.5176470588235295,0,0,1},{0.5019607843137255,0,0,1}};

    Bitmap drawSpectrogram(int[][] frequenciesData) {
//        var spectrCc = my.spectrCc;
        int height = getHeight();
        int width = getWidth() - 60;
        int[][] pixels = resample(frequenciesData);
        int heightFactor = bufferSize > 0 ? 2 : 1;
        int[] imageData = new int[width * height];
        for (int i = 0; i < pixels.length; i++) {
            for (int j = 0; j < pixels[i].length; j++) {
                double[] colorPoint = colorMap[pixels[i][j]];
                /* eslint-disable max-depth */

                for (int k = 0; k < heightFactor; k++) {
                    int y = height - j * heightFactor;

                    if (heightFactor == 2 && k == 1) {
                        y--;
                    }

                    int redIndex = y * width + i;
                    if (redIndex < width * height && redIndex >= 0)
                    {
                        imageData[redIndex] = Color.rgb((int) (colorPoint[0] * 255), (int) (colorPoint[1] * 255), (int) (colorPoint[2] * 255));
                    }
//                    imageData[redIndex + 1] = (int) (colorPoint[1] * 255);
//                    imageData[redIndex + 2] = (int) (colorPoint[2] * 255);
//                    imageData[redIndex + 3] = (int) (colorPoint[3] * 255);
                }
                /* eslint-enable max-depth */

            }
        }
        Bitmap b = Bitmap.createBitmap(imageData, width, height, Bitmap.Config.ARGB_8888);
        try {
            OutputStream outputStream = Files.newOutputStream(Paths.get(cachePath));
            b.compress(Bitmap.CompressFormat.PNG, 0, outputStream);
            outputStream.flush();
            outputStream.close();
        }catch (Exception ignored)
        {

        }
        return b;
    }
}
