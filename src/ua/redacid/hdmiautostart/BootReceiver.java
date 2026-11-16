package ua.redacid.hdmiautostart;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;

/** On boot, switches the MStar TV player to HDMI2 (inputSrc 24 = E_INPUT_SOURCE_HDMI2). */
public class BootReceiver extends BroadcastReceiver implements Runnable {
    private static final int INPUT_SRC_HDMI2 = 24;
    private static final long DELAY_MS = 4000; // let Kivi launcher finish starting first

    private Context context;
    private PendingResult result;

    @Override
    public void onReceive(Context ctx, Intent intent) {
        context = ctx.getApplicationContext();
        result = goAsync();
        new Handler(Looper.getMainLooper()).postDelayed(this, DELAY_MS);
    }

    @Override
    public void run() {
        try {
            Intent tv = new Intent("com.mstar.android.intent.action.START_TV_PLAYER");
            tv.setComponent(new ComponentName(
                    "com.mstar.tv.tvplayer.ui", "com.mstar.tv.tvplayer.ui.RootActivity"));
            tv.putExtra("inputSrc", INPUT_SRC_HDMI2);
            tv.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(tv);
        } finally {
            result.finish();
        }
    }
}
