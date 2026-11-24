package com.preetam.focus

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import android.system.Os
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Speaks with Phonon and reports, from the speaker's actual playback
 * position, how many characters of the text have been spoken so far, so the
 * chat can reveal the reply in step with the voice.
 *
 * Events: `{"pos": Int}` while speaking, then `{"done": true}` or `{"error": String}`.
 */
object PhononSpeaker : EventChannel.StreamHandler {
    private const val RATE = 24000
    // Rough speaking rate, only used until a sentence's real length is known.
    private const val FRAMES_PER_CHAR = 1700L

    private val exec = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var tts: PhononTTS? = null
    private var loadedDir: String? = null
    @Volatile private var gen = 0
    private var sink: EventChannel.EventSink? = null

    override fun onListen(args: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(args: Any?) { sink = null }

    private fun emit(m: Map<String, Any>) = main.post { sink?.success(m) }

    fun libraryLoads(): Boolean = try {
        System.loadLibrary("ptts_ffi"); true
    } catch (e: Throwable) { false }

    fun modelReady(dir: String) = listOf("config.json", "tokenizer.json", "model.q8.gguf")
        .all { File(dir, it).exists() } && libraryLoads()

    fun stop() { gen++ }

    /** Loads the model ahead of the first reply so speech starts quickly. */
    fun warm(dir: String) = exec.execute { runCatching { load(dir) } }

    private fun load(dir: String): PhononTTS {
        tts?.let { if (loadedDir == dir) return it }
        tts?.close()
        Os.setenv("RAYON_NUM_THREADS", "2", true)
        return PhononTTS(dir, "en").also { tts = it; loadedDir = dir }
    }

    private class Segment(val startFrame: Long, val chars: IntRange) {
        @Volatile var endFrame = -1L
    }

    fun speak(dir: String, text: String): Int {
        val my = ++gen
        exec.execute {
            var track: AudioTrack? = null
            try {
                val engine = load(dir)
                val min = AudioTrack.getMinBufferSize(RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
                track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setSampleRate(RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                    .setBufferSizeInBytes(min * 2)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
                track.play()
                val segments = java.util.concurrent.CopyOnWriteArrayList<Segment>()
                val written = java.util.concurrent.atomic.AtomicLong()
                val finished = java.util.concurrent.atomic.AtomicBoolean()
                val t = track
                val poller = Thread {
                    var last = -1
                    while (my == gen && !finished.get()) {
                        val head = t.playbackHeadPosition.toLong()
                        val seg = segments.lastOrNull { it.startFrame <= head }
                        if (seg != null) {
                            val len = seg.chars.last - seg.chars.first + 1
                            val end = if (seg.endFrame >= 0) seg.endFrame
                                else maxOf(written.get(), seg.startFrame + len * FRAMES_PER_CHAR)
                            val f = ((head - seg.startFrame).toDouble() / maxOf(1L, end - seg.startFrame)).coerceIn(0.0, 1.0)
                            val pos = seg.chars.first + (len * f).toInt()
                            if (pos != last) { last = pos; emit(mapOf("id" to my, "pos" to pos)) }
                        }
                        Thread.sleep(50)
                    }
                }
                poller.start()
                for (m in Regex("[^.!?\\n]+[.!?]*\\s*").findAll(text)) {
                    if (my != gen) break
                    if (m.value.isBlank()) continue
                    val seg = Segment(written.get(), m.range)
                    segments += seg
                    engine.speak(m.value.trim()) { pcm ->
                        if (my != gen) return@speak false
                        t.write(pcm, 0, pcm.size, AudioTrack.WRITE_BLOCKING)
                        written.addAndGet(pcm.size.toLong())
                        true
                    }
                    seg.endFrame = written.get()
                }
                while (my == gen && t.playbackHeadPosition.toLong() < written.get()) Thread.sleep(40)
                finished.set(true)
                poller.join(200)
                if (my == gen) emit(mapOf("id" to my, "pos" to text.length))
                emit(mapOf("id" to my, "done" to true))
            } catch (e: Throwable) {
                emit(mapOf("id" to my, "error" to (e.message ?: e.toString())))
            } finally {
                runCatching { track?.pause(); track?.flush(); track?.release() }
            }
        }
        return my
    }
}
