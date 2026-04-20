package com.jais.haven;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaRecorder;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.Build;
import android.os.Environment;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;

public class ChunkAudioRecordingService extends Service {

    public static final String ACTION_START = "com.jais.haven.action.START_CHUNK_RECORDING";
    public static final String ACTION_STOP = "com.jais.haven.action.STOP_CHUNK_RECORDING";

    private static final String TAG = "ChunkAudioRecording";
    private static final String CHANNEL_ID = "haven_audio_recording_channel";
    private static final int NOTIFICATION_ID = 6001;
    private static final long CHUNK_DURATION_MS = 20_000L;
    private static final long CHUNK_DURATION_US = CHUNK_DURATION_MS * 1000L;

    private static volatile boolean isRecordingActive = false;
    private static volatile long recordingStartedAtMs = 0L;
    private static volatile String recordingDirectoryPath = "";
    private static volatile String currentChunkPath = "";

    private MediaRecorder mediaRecorder;
    private File sessionFile;
    private File recordingDir;

    public static boolean isRecordingActive() {
        return isRecordingActive;
    }

    public static long getRecordingStartedAtMs() {
        return recordingStartedAtMs;
    }

    public static String getRecordingDirectoryPath() {
        return recordingDirectoryPath;
    }

    public static String getCurrentChunkPath() {
        return currentChunkPath;
    }

    public static long getChunkDurationMs() {
        return CHUNK_DURATION_MS;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        recordingDir = new File(getExternalFilesDir(Environment.DIRECTORY_MUSIC), "sos_chunks");
        if (!recordingDir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            recordingDir.mkdirs();
        }
        recordingDirectoryPath = recordingDir.getAbsolutePath();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final String action = intent == null ? null : intent.getAction();
        if (ACTION_STOP.equals(action)) {
            stopRecordingLoop();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }

        startForeground(NOTIFICATION_ID, buildNotification());
        startRecordingLoop();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        if (isRecordingActive) {
            stopRecordingLoop();
        }
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void startRecordingLoop() {
        if (isRecordingActive) {
            return;
        }

        isRecordingActive = true;
        recordingStartedAtMs = System.currentTimeMillis();

        if (!startRecorderForSession()) {
            isRecordingActive = false;
            recordingStartedAtMs = 0L;
            currentChunkPath = "";
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
        }
    }

    private void stopRecordingLoop() {
        if (!isRecordingActive && mediaRecorder == null) {
            return;
        }

        isRecordingActive = false;
        recordingStartedAtMs = 0L;

        final File finishedSession = stopRecorderSafely();
        if (finishedSession != null && finishedSession.exists() && finishedSession.length() > 0) {
            splitSessionIntoChunks(finishedSession);
            //noinspection ResultOfMethodCallIgnored
            finishedSession.delete();
        }

        currentChunkPath = "";
    }

    private boolean startRecorderForSession() {
        final String fileName = "session_" + System.currentTimeMillis() + ".m4a";
        sessionFile = new File(recordingDir, fileName);
        currentChunkPath = sessionFile.getAbsolutePath();

        mediaRecorder = new MediaRecorder();
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        mediaRecorder.setAudioSamplingRate(44_100);
        mediaRecorder.setAudioEncodingBitRate(128_000);
        mediaRecorder.setOutputFile(sessionFile.getAbsolutePath());

        try {
            mediaRecorder.prepare();
            mediaRecorder.start();
            return true;
        } catch (IOException | RuntimeException ex) {
            Log.e(TAG, "Unable to start audio chunk recorder", ex);
            releaseRecorder();
            return false;
        }
    }

    private File stopRecorderSafely() {
        final File completedFile = sessionFile;
        if (mediaRecorder == null) {
            return completedFile;
        }

        try {
            mediaRecorder.stop();
        } catch (RuntimeException ex) {
            Log.w(TAG, "Recorder stop failed for session", ex);
            if (sessionFile != null && sessionFile.exists()) {
                //noinspection ResultOfMethodCallIgnored
                sessionFile.delete();
            }
            releaseRecorder();
            return null;
        }
        releaseRecorder();
        return completedFile;
    }

    private void releaseRecorder() {
        if (mediaRecorder != null) {
            try {
                mediaRecorder.reset();
            } catch (Exception ignored) {
            }
            mediaRecorder.release();
            mediaRecorder = null;
        }
        sessionFile = null;
        if (!isRecordingActive) {
            currentChunkPath = "";
        }
    }

    private void splitSessionIntoChunks(File sourceFile) {
        MediaExtractor extractor = new MediaExtractor();
        MediaMuxer muxer = null;
        try {
            extractor.setDataSource(sourceFile.getAbsolutePath());

            int audioTrackIndex = -1;
            MediaFormat audioFormat = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat format = extractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    audioTrackIndex = i;
                    audioFormat = format;
                    break;
                }
            }

            if (audioTrackIndex < 0 || audioFormat == null) {
                return;
            }

            extractor.selectTrack(audioTrackIndex);

            ByteBuffer buffer = ByteBuffer.allocate(256 * 1024);
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();

            long chunkStartUs = -1L;
            int outputTrack = -1;
            int chunkIndex = 0;

            while (true) {
                long sampleTimeUs = extractor.getSampleTime();
                if (sampleTimeUs < 0) {
                    break;
                }

                if (muxer == null || (chunkStartUs >= 0 && sampleTimeUs - chunkStartUs >= CHUNK_DURATION_US)) {
                    if (muxer != null) {
                        try {
                            muxer.stop();
                        } catch (Exception ignored) {
                        }
                        muxer.release();
                    }

                    String outName = "chunk_" + System.currentTimeMillis() + "_" + chunkIndex++ + ".m4a";
                    File chunkFile = new File(recordingDir, outName);
                    muxer = new MediaMuxer(chunkFile.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
                    outputTrack = muxer.addTrack(audioFormat);
                    muxer.start();
                    chunkStartUs = sampleTimeUs;
                }

                info.offset = 0;
                info.size = extractor.readSampleData(buffer, 0);
                if (info.size < 0) {
                    break;
                }
                info.presentationTimeUs = sampleTimeUs - chunkStartUs;
                info.flags = extractor.getSampleFlags();
                muxer.writeSampleData(outputTrack, buffer, info);
                extractor.advance();
            }
        } catch (Exception ex) {
            Log.e(TAG, "Failed to split recording session into chunks", ex);
        } finally {
            try {
                extractor.release();
            } catch (Exception ignored) {
            }
            if (muxer != null) {
                try {
                    muxer.stop();
                } catch (Exception ignored) {
                }
                try {
                    muxer.release();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private Notification buildNotification() {
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(getString(R.string.audio_recording_notification_title))
                .setContentText(getString(R.string.audio_recording_notification_text))
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        final NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                getString(R.string.audio_recording_channel_name),
                NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription(getString(R.string.audio_recording_channel_description));

        final NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.createNotificationChannel(channel);
        }
    }
}
