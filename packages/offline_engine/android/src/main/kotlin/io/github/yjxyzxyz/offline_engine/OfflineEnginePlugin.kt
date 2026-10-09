package io.github.yjxyzxyz.offline_engine

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.*

class OfflineEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "lingoscribe/offline_engine")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "protectDirectory") { result.success(null); return }
        if (call.method != "normalize") { result.notImplemented(); return }
        val source = call.argument<String>("source")
        val destination = call.argument<String>("destination")
        if (source == null || destination == null || source == destination) { result.error("arguments", "Invalid paths", null); return }
        worker.execute {
            try {
                val duration = normalize(source, destination)
                main.post { result.success(duration) }
            } catch (error: Exception) {
                File(destination).delete()
                main.post { result.error("decode", error.message ?: "Audio decoding failed", null) }
            }
        }
    }

    private fun normalize(source: String, destination: String): Long {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var started = false
        try {
            extractor.setDataSource(source)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IllegalArgumentException("No audio track or unsupported format")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val advertised = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
            require(advertised <= 7_200_000_000L) { "Audio exceeds two hours" }
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            if (format.getString(MediaFormat.KEY_MIME) == "audio/raw") {
                return normalizeRaw(extractor, format, destination)
            }
            decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            decoder.configure(format, null, null, 0)
            decoder.start(); started = true
            val codec = requireNotNull(decoder)
            val info = MediaCodec.BufferInfo()
            var inputEnded = false
            var outputEnded = false
            var written = 0L
            BufferedOutputStream(FileOutputStream(destination), 65536).use { out ->
                out.write(ByteArray(44))
                fun writeSample(sample: Double) {
                    check(written < 16000L * 7200) { "Audio exceeds two hours" }
                    val pcm = (sample.coerceIn(-1.0, 1.0) * 32767).roundToInt()
                    out.write(pcm and 255); out.write((pcm shr 8) and 255); written++
                }
                var resampler = Resampler(rate, ::writeSample)
                var frames = 0L
                while (!outputEnded) {
                    if (!inputEnded) {
                        val index = codec.dequeueInputBuffer(10000)
                        if (index >= 0) {
                            val buffer = codec.getInputBuffer(index)!!
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputEnded = true
                            } else {
                                codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0); extractor.advance()
                            }
                        }
                    }
                    val index = codec.dequeueOutputBuffer(info, 10000)
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val actual = codec.outputFormat
                        val actualRate = actual.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        require(frames == 0L || actualRate == rate) { "Changing sample rate is unsupported" }
                        rate = actualRate; channels = actual.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        require(channels in 1..8 && rate in 8000..192000) { "Unsupported audio format" }
                        encoding = if (actual.containsKey(MediaFormat.KEY_PCM_ENCODING)) actual.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                        require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) { "Unsupported PCM encoding" }
                        if (frames == 0L) resampler = Resampler(rate, ::writeSample)
                    } else if (index >= 0) {
                        try {
                            val buffer = codec.getOutputBuffer(index)!!.order(ByteOrder.LITTLE_ENDIAN)
                            buffer.position(info.offset); buffer.limit(info.offset + info.size)
                            val frameBytes = channels * if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                            require(info.size % frameBytes == 0) { "Invalid PCM frame" }
                            while (buffer.remaining() >= frameBytes) {
                                var sample = 0.0
                                repeat(channels) { sample += if (encoding == AudioFormat.ENCODING_PCM_FLOAT) buffer.float.toDouble() else buffer.short / 32768.0 }
                                resampler.add(sample / channels); frames++
                            }
                            outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        } finally { codec.releaseOutputBuffer(index, false) }
                    }
                }
                resampler.finish()
            }
            require(written > 0) { "No decoded audio" }
            RandomAccessFile(destination, "rw").use { file ->
                fun short(value: Int) { file.write(value and 255); file.write((value shr 8) and 255) }
                fun int(value: Long) { repeat(4) { file.write(((value shr (8 * it)) and 255).toInt()) } }
                file.seek(0); file.writeBytes("RIFF"); int(36 + written * 2); file.writeBytes("WAVEfmt ")
                int(16); short(1); short(1); int(16000); int(32000); short(2); short(16)
                file.writeBytes("data"); int(written * 2)
            }
            return written / 16
        } finally {
            if (started) decoder?.stop()
            decoder?.release(); extractor.release()
        }
    }

    private fun normalizeRaw(extractor: MediaExtractor, format: MediaFormat, destination: String): Long {
        val rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val encoding = if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) format.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
        require(channels in 1..8 && rate in 8000..192000) { "Unsupported raw audio format" }
        require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) { "Only PCM16 and float WAV are supported" }
        val frameBytes = channels * if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
        val buffer = java.nio.ByteBuffer.allocateDirect(2 * 1024 * 1024).order(ByteOrder.LITTLE_ENDIAN)
        var written = 0L
        BufferedOutputStream(FileOutputStream(destination), 65536).use { out ->
            out.write(ByteArray(44))
            val resampler = Resampler(rate) { sample ->
                check(written < 16000L * 7200) { "Audio exceeds two hours" }
                val value = (sample.coerceIn(-1.0, 1.0) * 32767).roundToInt()
                out.write(value and 255); out.write((value shr 8) and 255); written++
            }
            while (true) {
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                require(size % frameBytes == 0) { "Invalid PCM frame" }
                buffer.position(0); buffer.limit(size)
                while (buffer.remaining() >= frameBytes) {
                    var sample = 0.0
                    repeat(channels) { sample += if (encoding == AudioFormat.ENCODING_PCM_FLOAT) buffer.float.toDouble() else buffer.short / 32768.0 }
                    resampler.add(sample / channels)
                }
                extractor.advance()
            }
            resampler.finish()
        }
        require(written > 0) { "No decoded audio" }
        RandomAccessFile(destination, "rw").use { file ->
            fun short(value: Int) { file.write(value and 255); file.write((value shr 8) and 255) }
            fun int(value: Long) { repeat(4) { file.write(((value shr (8 * it)) and 255).toInt()) } }
            file.seek(0); file.writeBytes("RIFF"); int(36 + written * 2); file.writeBytes("WAVEfmt ")
            int(16); short(1); short(1); int(16000); int(32000); short(2); short(16)
            file.writeBytes("data"); int(written * 2)
        }
        return written / 16
    }

    // Windowed-sinc low-pass resampling prevents aliasing when importing 44.1/48 kHz audio.
    private class Resampler(private val rate: Int, private val output: (Double) -> Unit) {
        private val ring = DoubleArray(128)
        private var input = 0L
        private var next = 0L
        private val cutoff = min(1.0, 16000.0 / rate) * 0.94
        fun add(value: Double) {
            ring[(input % 128).toInt()] = if (value.isFinite()) value else 0.0
            input++
            emit(input - 17.0, Long.MAX_VALUE)
        }
        private fun emit(available: Double, limit: Long) {
            while (next.toDouble() * rate / 16000 <= available && next < limit) {
                val center = next.toDouble() * rate / 16000
                var sum = 0.0; var weight = 0.0
                val base = floor(center).toLong()
                for (i in base - 15..base + 16) {
                    val distance = center - i
                    val x = PI * distance * cutoff
                    val sinc = if (abs(x) < 1e-9) 1.0 else sin(x) / x
                    val w = sinc * cutoff * (0.5 + 0.5 * cos(PI * distance / 17))
                    if (i >= 0 && i < input && input - i <= 128) sum += ring[(i % 128).toInt()] * w
                    weight += w
                }
                output(if (abs(weight) < 1e-9) 0.0 else sum / weight); next++
            }
        }
        fun finish() { emit(input + 16.0, (input * 16000 + rate - 1) / rate) }
    }
}
