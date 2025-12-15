package boying.sdk;

import android.util.Log;
import java.util.concurrent.atomic.AtomicBoolean;

public final class BoyingSdkManager {

    private static final String TAG = "BoyingSdkManager";

    private static volatile BoyingSdkManager instance;

    private final BoyingSdk sdk;

    private final AtomicBoolean inited  = new AtomicBoolean(false);
    private final AtomicBoolean started = new AtomicBoolean(false);

    private BoyingSdkManager() {
        sdk = BoyingSdk.getInstance();
    }

    public static BoyingSdkManager getInstance() {
        if (instance == null) {
            synchronized (BoyingSdkManager.class) {
                if (instance == null) {
                    instance = new BoyingSdkManager();
                }
            }
        }
        return instance;
    }

    /** 只允许初始化一次 */
    public void initSdk() {
        if (inited.compareAndSet(false, true)) {
            sdk.initSdk();
            Log.d(TAG, "SDK init OK");
        } else {
            Log.d(TAG, "SDK already inited, skip");
        }
    }

    /** 只允许启动一次 */
    public void startSdk() {
        if (!inited.get()) {
            Log.e(TAG, "startSdk called before initSdk!");
            return;
        }

        if (started.compareAndSet(false, true)) {
            sdk.startSdk();
            Log.d(TAG, "SDK start OK");
        } else {
            Log.d(TAG, "SDK already started, skip");
        }
    }

    /** 幂等 stop */
    public void stopSdk() {
        if (started.compareAndSet(true, false)) {
            sdk.stopSdk();
            Log.d(TAG, "SDK stopped");
        }
    }

    /** 对外只暴露“安全接口” */
    public byte[] sendCmdSafe(String json) {
        if (!started.get()) {
            Log.e(TAG, "sendCmdSafe but SDK not started");
            return null;
        }
        return sdk.sendCmd(
            com.alibaba.fastjson.JSONObject.parseObject(json)
        );
    }

    public BoyingSdk rawSdk() {
        return sdk;
    }
}