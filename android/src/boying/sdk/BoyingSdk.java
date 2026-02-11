package boying.sdk;

import android.text.TextUtils;
import android.util.Log;
import android.util.SparseIntArray;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.test.sdk.log.Logs;

import java.util.Calendar;

/**
 * Author:Xujingtao
 * Date:2023/12/8
 */
public class BoyingSdk
{
    private final static String TAG = "BoyingSdk";

    //获得规划好的航线
    private native String GetRoute(String inputJson);

    //获得点偏移
    private native String GetMovePoint(String inputJson);

    //启动串口链接  ！！只能调用一次
    private native void StartFlightController(String inputJson);

    //重新启动串口链接
    private native void RestartFlightController();

    //关闭串口
    private native void CloseFlightController();

    //重新设置串口数据
    private native void SetFlightController(String inputJson);

    //获得串口数据
    private native String GetMsg();

    //推送串口数据
    private native void PushMsg(String inputJson);

    //获得版本号
    private native String GetVersion();

    //通过二进制字节数组获得 json消息，二进制里有多少消息返回多少消息
    private native String GetMsgByByte(byte[] b, int len);

    //通过json消息压缩二进制数组，一次发一个json消息
    private native byte[] GetByteByMsg(String inputJson);

    //初始化消息解析器。
    private native int InitAnalyzer(String inputJson);

    //清空Msg数据。
    private native void ClearMsgData();

    //添加Msg数据，如果有，会覆盖。
    private native void PushMsgData(int k, String v);

    //添加Msg数据，是一个字符串类型，json格式，如果有，会覆盖。
    private native void PushMsgJsonData(String v);

    //清空CRC。
    private native void ClearCrcData();

    //添加CRC。
    private native void PushCrcData(int id, int crc);

    //创建PID控制器。 !!支持多线程，调用
    private native void CreatePID(String name, Double kp, Double ki, Double kd, Double target);

    //计算PID控制器。!!支持多线程，调用
    private native Double CalculatePID(String name, Double currentValue);

    //重新设置PID控制器。!!支持多线程，调用
    private native void ResetPID(String name, Double kp, Double ki, Double kd, Double target);

    //删除PID控制器。!!支持多线程，调用
    private native void RemovePID(String name);

    //通过二进制和二进制的长度获取json
    private native String GetJsonByByteJava(byte[] b, int len);

    //通过json获取二进制
    private native byte[] GetByteByJsonJava(String inputJson);

    private native String GetByByteAccountJava(String s, String  b, int l);
    private native String GetGGAJava();

    //循环获取sdk内的信息
    private native byte[] GetByteCommandJava();

    //运行sdk
    private native int StartSDKJava();

    //初始化
    private native int InitSDKJava();

    //停止
    private native int StopSDKJava();

    //通过json发送命令
    private native int SendCommandByJson(String inputJson);

    //是否在执行任务
    private native boolean IsMission();

    /**
     * 设置日志文件目录
     *
     * @param path
     */
    private native void SetLogFilePath(String path,String fileName);
    private native void TestWriteLog();


    static
    {
        System.loadLibrary("BoyingSdk");
    }

    /**
     * 获取规划结果
     *
     * @param inputJson
     * @return
     */
    public String getRoute(String inputJson)
    {
        return GetRoute(inputJson);
    }

    private volatile static BoyingSdk instance;
    private SparseIntArray msgIdMap;
    private boolean isInited = false;
    private boolean isStarted = false;

    public static BoyingSdk getInstance()
    {
        if (instance == null)
        {
            synchronized (BoyingSdk.class)
            {
                if (instance == null)
                {
                    instance = new BoyingSdk();
                }
            }
        }
        return instance;
    }

    private BoyingSdk()
    {
        Calendar calendar = Calendar.getInstance();
        String fileName = "log_" +
                                  calendar.get(Calendar.YEAR) + "_" +
                                  (calendar.get(Calendar.MONTH) + 1) + "_" +
                                  calendar.get(Calendar.DATE) + "_" +
                                  calendar.get(Calendar.HOUR) + "_" +
                                  calendar.get(Calendar.MINUTE) + "_" +
                                  calendar.get(Calendar.SECOND) +
                                  ".txt";


    }

    public void initSdk()
    {
        if (this.isInited())
        {
            return;
        }
        this.isInited = true;
        InitSDKJava();
        Log.d(TAG, "初始化SDK");
    }

    public byte[] getSdkData()
    {
        return GetByteCommandJava();
    }

    public void startSdk()
    {
        if (this.isStarted())
        {
            return;
        }
        this.isStarted = true;
        StartSDKJava();
        Log.d(TAG, "启动SDK");
    }

    public void stopSdk()
    {
        if (!this.isStarted())
        {
            return;
        }
        this.isStarted = false;
        StopSDKJava();
        Log.d(TAG, "停止SDK");
    }

    public byte[] sendCmd(JSONObject cmd)
    {
        Logs.d(TAG, "发送命令=" + cmd.toJSONString());
        return GetByteByJsonJava(cmd.toJSONString());
    }

    public int sendNewCmd(JSONObject cmd)
    {
        String str = cmd.toJSONString();
        Logs.d(TAG, "发送新版命令=" + str);
        Log.d(TAG, "发送新版命令"+str);
        int result = SendCommandByJson(str);
        if (result != 0)
        {
            String hint = "测试:SendCommandByJson返回" + result;
            Log.d(TAG, hint);
        }

        return result;
    }

    public JSONArray onReceive(byte[] bytes, int length)
    {
        //Log.d(TAG, MathUtil.bytesToLogtring(Arrays.copyOf(bytes, length)));
        String str = GetJsonByByteJava(bytes, length);
        //Log.d(TAG, "接收命令"+str);
        if (TextUtils.isEmpty(str))
        {
            return null;
        }
        try
        {
            JSONObject json = JSONObject.parseObject(str);
            //Log.d(TAG, "收到json=" + json.toJSONString());
            if (!json.containsKey("msg"))
            {
                //Log.d(TAG, "收到数据不包含msg");
                return null;
            }
            return json.getJSONArray("msg");
        } catch (Exception e)
        {
            Log.e(TAG, e.toString());
        }

        return null;
    }

    /**
     * ByType转msgID
     *
     * @param type
     * @return -1表示没有映射
     */
    public int byTypeToMsgId(int type)
    {
        int index = this.msgIdMap.indexOfValue(type);
        if (index < 0)
        {
            return -1;
        }
        return this.msgIdMap.keyAt(index);
    }

    /**
     * msgID转ByType
     *
     * @param msgId
     * @return -1表示没有映射
     */
    public int msgIdToByType(int msgId)
    {
        return this.msgIdMap.get(msgId, -1);
    }

    /**
     * 是否已初始化
     *
     * @return
     */
    public boolean isInited()
    {
        return isInited;
    }

    /**
     * 是否已启动
     *
     * @return
     */
    public boolean isStarted()
    {
        return isStarted;
    }


    public  String getByByteAccount(String s, String b, int l)
    {
        String account= GetByByteAccountJava(s, b, l);
        return account;
    }

    public  String getGGA()
    {
        String gga= GetGGAJava();
        //Logs.d(TAG,"发送给千寻的gga数据"+gga);
        return gga;
    }
}
