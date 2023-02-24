
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.Nullable;

import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;

//wavesurfer.js 波型图移植，目前只移植支持单声道
public class WavesurferWaveform extends View {

    int width, height;
    Paint paint1 = new Paint();
    Paint paint2 = new Paint();
    Paint paint3 = new Paint();
    double[] buffer;
    double percent = 0.0;
    private boolean isBackground = false;

    public WavesurferWaveform(Context context) {
        super(context);
    }

    public WavesurferWaveform(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public void setData(double[] buffer, boolean isBackground, String savePath)
    {
        this.isBackground = isBackground;
        this.buffer = buffer;
        this.cachePath = savePath;
        peaks = null;
        paint1.setColor(Color.parseColor("#4AAAFF"));
        paint1.setAntiAlias(false);
        paint2.setColor(Color.parseColor("#004D91"));
        paint2.setAntiAlias(false);
        paint3.setColor(Color.parseColor("#FB6013"));
        paint3.setAntiAlias(false);
        paint3.setStrokeWidth(2);
        invalidate();
    }

    String cachePath = "";
    public void setData(String path)
    {
        this.cachePath = path;
        isBackground = true;
        invalidate();
    }

    public void clearData()
    {
        this.cachePath = "";
        this.buffer = null;
        this.peaks = null;
        invalidate();
    }

    //暂定左隔60，与频谱对齐
    @Override
    protected void onDraw(Canvas canvas) {
        getPeaks();
        if (isBackground) {
            if (peaks != null)
            {
//                drawLineToContext(canvas);
                Bitmap bitmap = Bitmap.createBitmap(width + 60, height, Bitmap.Config.ARGB_8888);
                Canvas canvas1 = new Canvas(bitmap);
                drawLineToContext(canvas1);
                try {
                    OutputStream outputStream = Files.newOutputStream(Paths.get(cachePath));
                    bitmap.compress(Bitmap.CompressFormat.PNG, 0, outputStream);
                    outputStream.flush();
                    outputStream.close();
                }catch (Exception ignored)
                {

                }
            }
//            else
//            {
                canvas.drawBitmap(BitmapFactory.decodeFile(cachePath, new BitmapFactory.Options()), 0, 0, paint1);
//            }
        }
        else
        {
            drawLineToContextProgress(canvas);
        }
        super.onDraw(canvas);
    }

    double[] peaks;
    void getPeaks() {
        if (buffer == null || peaks != null)
        {
            return;
        }
        width = getWidth() - 60;
        height = getHeight();
        int first = 0;
        int last = width - 1;

        double sampleSize = ((double)this.buffer.length / width);
        int sampleStep = (int)Math.floor(sampleSize / 10);//(int)Math.floor等于js的"~~"
        int channels = 1;
        for (int c = 0; c < channels; c++) {
            peaks = new double[2 * width];
//            var chan = this.buffer.getChannelData(c);

            for (int i = first; i <= last; i++) {
                int start = (int)Math.floor(i * sampleSize);
                int end = (int)Math.floor(start + sampleSize);
                /**
                 * Initialize the max and min to the first sample of this
                 * subrange, so that even if the samples are entirely
                 * on one side of zero, we still return the true max and
                 * min values in the subrange.
                 */

                double min = buffer[start];
                double max = min;

                for (int j = start; j < end; j += sampleStep) {
                    double value = buffer[j];

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



    void drawLineToContext(Canvas canvas) {
//        var first = Math.round(length * this.start); // use one more peak value to make sure we join peaks at ends -- unless,
        // of course, this is the last canvas
        if (peaks == null || peaks.length == 0)
        {
            return;
        }
        int last = Math.round(peaks.length / 2f) + 1;
        int canvasStart = 0;
        double scale = 0.999253731343284; // optimization
        int halfOffset = Math.round(height / 2f);
        double absmaxHalf = (1 / 3f) / (height / 2f);
        Path path = new Path();
        path.moveTo((float) (canvasStart * scale + 60), (float) halfOffset);
        path.lineTo((float) (canvasStart * scale + 60), halfOffset - Math.round(peaks[2 * canvasStart] / absmaxHalf));

        for (int i = 0; i < last; i++) {
            double peak = 2 * i < peaks.length ? peaks[2 * i] : 0;
            long h = Math.round(peak / absmaxHalf);
            path.lineTo((float) (i * scale + 60), halfOffset - h);
        } // draw the bottom edge going backwards, to make a single
        // closed hull to fill


        for (int j = last - 1; j >= canvasStart; j--) {
            double peak = 2 * j + 1 < peaks.length ? peaks[2 * j + 1] : 0;
            long h = Math.round(peak / absmaxHalf);
            path.lineTo((float) (j * scale + 60), halfOffset - h);
        }

        path.lineTo((float) (canvasStart * scale + 60), halfOffset - Math.round((peaks[1]) / absmaxHalf));
        path.close();
        canvas.drawPath(path, paint1);
    }

    void drawLineToContextProgress(Canvas canvas) {
        if (peaks == null || peaks.length == 0)
        {
            return;
        }
        int length = peaks.length / 2;
        // use one more peak value to make sure we join peaks at ends -- unless,
        // of course, this is the last canvas

        int last = (int) Math.round((length + 1) * percent);
        int canvasStart = 0;
        double scale = 0.999253731343284; // optimization
        int halfOffset = height / 2;
        double absmaxHalf = (1 / 3f) / (height / 2f);
        Path path = new Path();
        path.moveTo((float) (canvasStart * scale) + 60, (float) halfOffset);
        path.lineTo((float) (canvasStart * scale) + 60, halfOffset - Math.round(peaks[2 * canvasStart] / absmaxHalf));

        for (int i = 0; i < last; i++) {
            double peak = 2 * i < peaks.length ? peaks[2 * i] : 0;
            long h = Math.round(peak / absmaxHalf);
            path.lineTo((float) (i * scale + 60), halfOffset - h);
        } // draw the bottom edge going backwards, to make a single
        // closed hull to fill


        for (int j = last - 1; j >= canvasStart; j--) {
            double peak = 2 * j + 1 < peaks.length ? peaks[2 * j + 1] : 0;
            long h = Math.round(peak / absmaxHalf);
            path.lineTo((float) (j * scale + 60), halfOffset - h);
        }

        path.lineTo((float) (canvasStart * scale + 60), halfOffset - Math.round((peaks[1]) / absmaxHalf));
        canvas.drawPath(path, paint2);
        canvas.drawLine((float) (last * scale + 60), -height, (float) (last * scale + 60), height, paint3);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        if (event.getX() >= 60 && !isBackground)
        {
//            setPercent((event.getX() - 60) / width);
            if (listener != null)
            {
                listener.onProgressTouch((event.getX() - 60) / width);
            }
        }
        return super.dispatchTouchEvent(event);
    }

    public void setPercent(double d)
    {
        percent = d;
        invalidate();
    }

    private OnProgressTouchListener listener;

    public void setListener(OnProgressTouchListener listener) {
        this.listener = listener;
    }

    public interface OnProgressTouchListener
    {
        void onProgressTouch(double d);
    }

}
