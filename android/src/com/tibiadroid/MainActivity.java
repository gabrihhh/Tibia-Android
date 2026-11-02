package com.tibiadroid;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

/**
 * Tela de entrada: dispara o serviço do jogo, mostra o progresso (preparação,
 * atualização) e abre a tela do jogo (Termux:X11) quando o cliente sobe.
 */
public class MainActivity extends Activity implements TibiaService.Listener {
    private static final String X11_PACKAGE = "com.termux.x11";

    private TextView status;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(Color.rgb(24, 18, 12));
        layout.setPadding(64, 64, 64, 64);
        status = new TextView(this);
        status.setTextColor(Color.rgb(230, 220, 200));
        status.setTextSize(18);
        status.setGravity(Gravity.CENTER);
        status.setPadding(0, 48, 0, 0);
        layout.addView(new ProgressBar(this));
        layout.addView(status);
        setContentView(layout);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!isInstalled(X11_PACKAGE)) {
            onStatus("Instale o app Termux:X11 para mostrar o jogo na tela.");
            return;
        }
        TibiaService.listener = this;
        if (TibiaService.gameReady) {
            onGameReady();
            return;
        }
        onStatus(TibiaService.lastStatus.isEmpty() ? "Iniciando…" : TibiaService.lastStatus);
        if (!TibiaService.running) startForegroundService(new Intent(this, TibiaService.class));
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (TibiaService.listener == this) TibiaService.listener = null;
    }

    @Override
    public void onStatus(String message) {
        runOnUiThread(() -> status.setText(message));
    }

    @Override
    public void onGameReady() {
        runOnUiThread(() -> {
            Intent i = getPackageManager().getLaunchIntentForPackage(X11_PACKAGE);
            if (i != null) {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            }
        });
    }

    private boolean isInstalled(String pkg) {
        try {
            getPackageManager().getPackageInfo(pkg, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }
}
