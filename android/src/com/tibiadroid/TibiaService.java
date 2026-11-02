package com.tibiadroid;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

/**
 * Faz todo o trabalho em primeiro plano: prepara o ambiente, atualiza o cliente,
 * sobe o servidor X (Termux:X11), o servidor de GPU (virgl) e o Tibia, e encerra
 * tudo quando o cliente fecha.
 *
 * Precisa ser um serviço em primeiro plano: o Android corta a rede e congela os
 * processos de apps em segundo plano, e durante o jogo quem está na frente é a
 * tela do Termux:X11.
 */
public class TibiaService extends Service {
    static final String ACTION_STOP = "com.tibiadroid.STOP";
    private static final String TAG = "TibiaDroid";
    private static final String CHANNEL = "tibia";

    /** Recebe o progresso para mostrar na tela inicial. */
    interface Listener {
        void onStatus(String message);

        void onGameReady();
    }

    static volatile boolean running;
    static volatile boolean gameReady;
    static volatile String lastStatus = "";
    static volatile Listener listener;

    private final List<Process> processes = new ArrayList<>();
    private PowerManager.WakeLock wakeLock;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopAll();
            return START_NOT_STICKY;
        }
        if (running) return START_NOT_STICKY;
        running = true;
        gameReady = false;
        startForeground(1, buildNotification());
        wakeLock = ((PowerManager) getSystemService(POWER_SERVICE))
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tibiadroid:game");
        wakeLock.acquire();
        new Thread(this::run, "tibia-launcher").start();
        return START_NOT_STICKY;
    }

    private void run() {
        File home = Paths.home(this);
        try {
            installRuntimeIfNeeded(home);
            boolean hasClient = new File(home, "Tibia/bin/client").exists();
            status(hasClient ? "Procurando atualizações do Tibia…" : "Baixando o Tibia (primeira vez, ~700 MB)…");
            if (runUpdate(home) != 0 && !new File(home, "Tibia/bin/client").exists()) {
                status("Não foi possível baixar o Tibia. Verifique a internet e abra o app de novo.");
                return;
            }
            status("Abrindo o Tibia…");
            start(home, "x11");
            waitForSocket(new File(home, "tmp/.X11-unix/X0").getPath(), "o servidor X (Termux:X11)");
            start(home, "virgl");
            // sem conexão de teste aqui: no modo --multi-clients, um cliente que
            // conecta e desconecta deixa o virgl sem responder ao próximo (o Mesa)
            Thread.sleep(2000);
            Process client = start(home, "tibia");
            gameReady = true;
            Listener l = listener;
            if (l != null) l.onGameReady();
            int code = client.waitFor();
            Log.i(TAG, "cliente terminou com código " + code);
        } catch (Exception e) {
            Log.e(TAG, "falha ao iniciar o jogo", e);
            status("Erro: " + e.getMessage());
        } finally {
            stopAll();
        }
    }

    /** Extrai o runtime do APK quando o app é instalado ou atualizado. */
    private void installRuntimeIfNeeded(File home) throws Exception {
        PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
        File marker = new File(home, ".runtime-version");
        String expected = info.getLongVersionCode() + ":" + info.lastUpdateTime;
        if (marker.exists() && new String(Files.readAllBytes(marker.toPath()), StandardCharsets.UTF_8).equals(expected)) {
            return;
        }
        status("Preparando o ambiente (só na primeira vez)…");
        // apaga o runtime antigo, mas mantém o cliente baixado (Tibia/)
        File[] old = home.listFiles();
        if (old != null) for (File f : old) if (!f.getName().equals("Tibia")) Installer.deleteRecursive(f);
        home.mkdirs();
        Installer.extractTarGz(getAssets().open("runtime.tar.gz"), home, this::status);
        Installer.patchVirgl(new File(home, "virgl/virgl_server"), new File(home, "virgl"));
        // o Android 14+ só carrega dex/apk somente-leitura (CLASSPATH do app_process)
        new File(home, "x11-loader.apk").setWritable(false, false);
        try (FileOutputStream os = new FileOutputStream(marker)) {
            os.write(expected.getBytes(StandardCharsets.UTF_8));
        }
    }

    /** Roda o atualizador (tibia-fetch.py) e repassa as linhas de progresso. */
    private int runUpdate(File home) throws Exception {
        Process p = start(home, "update", true);
        try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = r.readLine()) != null) {
                Log.i(TAG, "update: " + line);
                String l = line.trim();
                if (l.startsWith("tibiaclient")) status("Verificando o cliente…");
                else if (l.startsWith("assets")) status("Verificando os arquivos do jogo…");
                else if (l.matches("\\d+/\\d+ .*")) status("Baixando: " + l);
            }
        }
        int code = p.waitFor();
        synchronized (processes) {
            processes.remove(p);
        }
        return code;
    }

    /** Espera um socket Unix abstrato aceitar conexões (o servidor está pronto). */
    private void waitForSocket(String abstractName, String what) throws Exception {
        for (int i = 0; i < 100; i++) {
            try (LocalSocket s = new LocalSocket()) {
                s.connect(new LocalSocketAddress(abstractName, LocalSocketAddress.Namespace.ABSTRACT));
                return;
            } catch (IOException e) {
                Thread.sleep(200);
            }
        }
        throw new IOException("tempo esgotado esperando " + what);
    }

    private Process start(File home, String name) throws IOException {
        return start(home, name, false);
    }

    private Process start(File home, String name, boolean pipeOutput) throws IOException {
        ProcessBuilder pb = new ProcessBuilder("/system/bin/sh", new File(home, "bin/" + name + ".sh").getPath());
        pb.environment().put("TIBIA_HOME", home.getPath());
        pb.redirectErrorStream(true);
        if (!pipeOutput) {
            File logs = new File(home, "logs");
            logs.mkdirs();
            pb.redirectOutput(new File(logs, name + ".log"));
        }
        Process p = pb.start();
        synchronized (processes) {
            processes.add(p);
        }
        return p;
    }

    private void status(String message) {
        lastStatus = message;
        Listener l = listener;
        if (l != null) l.onStatus(message);
    }

    private void stopAll() {
        synchronized (processes) {
            for (Process p : processes) p.destroy();
            processes.clear();
        }
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        running = false;
        gameReady = false;
        stopForeground(true);
        stopSelf();
    }

    private Notification buildNotification() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Jogo em execução", NotificationManager.IMPORTANCE_LOW));
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stop = PendingIntent.getService(this, 1, new Intent(this, TibiaService.class).setAction(ACTION_STOP),
                PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle("Tibia em execução")
                .setContentText("Toque para voltar ao jogo")
                .setContentIntent(open)
                .addAction(new Notification.Action.Builder(null, "Encerrar", stop).build())
                .setOngoing(true)
                .build();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
