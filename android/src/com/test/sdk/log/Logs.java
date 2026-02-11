package com.test.sdk.log;

import android.os.Build;
import android.os.Environment;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

// import com.test.sdk.BuildConfig;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


import timber.log.Timber;

/**
 * 日志工具类
 */
public class Logs
{
    private static final Pattern ANONYMOUS_CLASS = Pattern.compile("(\\$\\d+)+$");

    private final static String TAG_SPLITTER = "@@@";

    /**
     * 是否已初始化
     */
    private static boolean isInited = false;

    /**
     * 是否启用远程日志
     */
    private static boolean enableRemoteLog = false;

    /**
     * 是否启用远程日志
     *
     * @return
     */
    public static boolean isEnableRemoteLog()
    {
        return enableRemoteLog;
    }

    /**
     * 是否启用远程日志
     *
     * @param enableRemoteLog
     */
    public static void setEnableRemoteLog(boolean enableRemoteLog)
    {
        Logs.enableRemoteLog = enableRemoteLog;
    }

    /**
     * 初始化
     */
    public static synchronized void init()
    {
        if (isInited())
        {
            return;
        }
        Log.d("日志保存","路径"+ Environment.getExternalStorageDirectory() .getAbsolutePath());
        isInited = true;
        List<Timber.Tree> list = new ArrayList<>();
        //控制台
        // list.add(new LogCatTree());
        // list.add(new RollingFileLogTree());

        Timber.plant(list.toArray(new Timber.Tree[0]));
    }

    /**
     * 是否已初始化
     *
     * @return
     */
    public static boolean isInited()
    {
        return isInited;
    }

    /**
     * 是否是release版
     *
     * @return
     */
    public static boolean isRelease()
    {
        return true;
    }

    /**
     * 合并module和tag
     *
     * @param module
     * @param tag
     * @return 返回<b>module分隔符tag</b>的形式
     */
    @NonNull
    public static String mergeModuleTag(@NonNull String module, @NonNull String tag)
    {
        if (TextUtils.isEmpty(module) && TextUtils.isEmpty(tag))
        {
            return "";
        }
        if (TextUtils.isEmpty(module))
        {
            return tag + TAG_SPLITTER + tag;
        }
        else if (TextUtils.isEmpty(tag))
        {
            return module + TAG_SPLITTER + module;
        }
        else
        {
            return module + TAG_SPLITTER + tag;
        }
    }

    /**
     * 分离module和tag
     *
     * @param sourceTag 原始tag,是<b>module分隔符tag</b>的形式
     * @return 根据分隔符拆分sourceTag, 可能返回3种情况
     * <li>空字符串,空字符串</li>
     * <li>空字符串,tag</li>
     * <li>module,tag</li>
     */
    @NonNull
    public static String[] splitModuleTag(@Nullable String sourceTag)
    {
        if (TextUtils.isEmpty(sourceTag))
        {
            return new String[]{"", ""};
        }
        if (!sourceTag.contains(TAG_SPLITTER))
        {
            return new String[]{"", sourceTag};
        }
        String[] strs = sourceTag.split(TAG_SPLITTER);
        if (strs.length == 0)
        {
            return new String[]{"", ""};
        }
        if (strs.length == 1)
        {
            return new String[]{"", strs[0]};
        }
        return new String[]{strs[0], strs[1]};
    }

    /**
     * 获取tag,参考自DebugTree的getTag方法
     *
     * @return
     */
    public static String getTag()
    {
        StackTraceElement[] elements = (new Throwable()).getStackTrace();
        if (elements.length < 3)
        {
            return null;
        }
        StackTraceElement element = elements[2];
        String tag = element.getClassName();
        Matcher m = ANONYMOUS_CLASS.matcher(tag);
        if (m.find())
        {
            tag = m.replaceAll("");
        }

        tag = tag.substring(tag.lastIndexOf(46) + 1);
        return tag.length() > 23 && Build.VERSION.SDK_INT < Build.VERSION_CODES.M ? tag.substring(0, 23) : tag;
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param message
     * @param args
     */
    public static void v(String message, Object... args)
    {
        v(getTag(), message, args);
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void v(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.v(message, args);
        }
        else
        {
            Timber.tag(tag).v(message, args);
        }
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param t
     */
    public static void v(Throwable t)
    {
        v(getTag(), t);
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param tag
     * @param t
     */
    public static void v(String tag, Throwable t)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.v(t);
        }
        else
        {
            Timber.tag(tag).v(t);
        }
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param t
     * @param message
     * @param args
     */
    public static void v(Throwable t, String message, Object... args)
    {
        v(getTag(), t, message, args);
    }

    /**
     * verbose,release版无效,此级别日志不写入文件,仅在控制台显示
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void v(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.v(t, message, args);
        }
        else
        {
            Timber.tag(tag).v(t, message, args);
        }
    }

    /**
     * debug,release版无效
     *
     * @param message
     * @param args
     */
    public static void d(String message, Object... args)
    {
        d(getTag(), message, args);
    }

    /**
     * debug,release版无效
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void d(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.d(message, args);
        }
        else
        {
            Timber.tag(tag).d(message, args);
        }
    }

    /**
     * debug,release版无效
     *
     * @param t
     */
    public static void d(Throwable t)
    {
        d(getTag(), t);
    }

    /**
     * debug,release版无效
     *
     * @param tag
     * @param t
     */
    public static void d(String tag, Throwable t)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.d(t);
        }
        else
        {
            Timber.tag(tag).d(t);
        }
    }

    /**
     * debug,release版无效
     *
     * @param t
     * @param message
     * @param args
     */
    public static void d(Throwable t, String message, Object... args)
    {
        d(getTag(), t, message, args);
    }

    /**
     * debug,release版无效
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void d(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.d(t, message, args);
        }
        else
        {
            Timber.tag(tag).d(t, message, args);
        }
    }

    /**
     * info,release版无效
     *
     * @param message
     * @param args
     */
    public static void i(String message, Object... args)
    {
        i(getTag(), message, args);
    }

    /**
     * info,release版无效
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void i(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.i(message, args);
        }
        else
        {
            Timber.tag(tag).i(message, args);
        }
    }

    /**
     * info,debug,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ii(@NonNull String module, @NonNull String tag, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).i(message, args);
    }

    /**
     * info,release版无效
     *
     * @param t
     */
    public static void i(Throwable t)
    {
        i(getTag(), t);
    }

    /**
     * info,release版无效
     *
     * @param tag
     * @param t
     */
    public static void i(String tag, Throwable t)
    {
        if (!isInited())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.i(t);
        }
        else
        {
            Timber.tag(tag).i(t);
        }
    }

    /**
     * info,debug,release版有效,发送远程日志
     *
     * @param module 模块,不能为空
     * @param tag    tag,不能为空
     * @param t      异常
     */
    public static void ii(@NonNull String module, @NonNull String tag, Throwable t)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).i(t);
    }

    /**
     * info,release版无效
     *
     * @param t
     * @param message
     * @param args
     */
    public static void i(Throwable t, String message, Object... args)
    {
        i(getTag(), t, message, args);
    }

    /**
     * info,release版无效
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void i(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.i(t, message, args);
        }
        else
        {
            Timber.tag(tag).i(t, message, args);
        }
    }

    /**
     * info,debug,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param t       异常
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ii(@NonNull String module, @NonNull String tag, Throwable t, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).i(t, message, args);
    }

    /**
     * warn,release版无效
     *
     * @param message
     * @param args
     */
    public static void w(String message, Object... args)
    {
        w(getTag(), message, args);
    }

    /**
     * warn,release版无效
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void w(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.w(message, args);
        }
        else
        {
            Timber.tag(tag).w(message, args);
        }
    }

    /**
     * warn,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ww(@NonNull String module, @NonNull String tag, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).w(message, args);
    }

    /**
     * warn,release版无效
     *
     * @param t
     */
    public static void w(Throwable t)
    {
        w(getTag(), t);
    }

    /**
     * warn,release版无效
     *
     * @param tag
     * @param t
     */
    public static void w(String tag, Throwable t)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.w(t);
        }
        else
        {
            Timber.tag(tag).w(t);
        }
    }

    /**
     * warn,release版有效,发送远程日志
     *
     * @param module 模块,不能为空
     * @param tag    tag,不能为空
     * @param t      异常
     */
    public static void ww(@NonNull String module, @NonNull String tag, Throwable t)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).w(t);
    }

    /**
     * warn,release版无效
     *
     * @param t
     * @param message
     * @param args
     */
    public static void w(Throwable t, String message, Object... args)
    {
        w(getTag(), t, message, args);
    }

    /**
     * warn,release版无效
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void w(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.w(t, message, args);
        }
        else
        {
            Timber.tag(tag).w(t, message, args);
        }
    }

    /**
     * warn,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param t       异常
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ww(@NonNull String module, @NonNull String tag, Throwable t, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).w(t, message, args);
    }

    /**
     * error,release版无效
     *
     * @param message
     * @param args
     */
    public static void e(String message, Object... args)
    {
        e(getTag(), message, args);
    }

    /**
     * error,release版无效
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void e(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.e(message, args);
        }
        else
        {
            Timber.tag(tag).e(message, args);
        }
    }

    /**
     * error,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ee(@NonNull String module, @NonNull String tag, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).e(message, args);
    }

    /**
     * error,release版无效
     *
     * @param t
     */
    public static void e(Throwable t)
    {
        e(getTag(), t);
    }

    /**
     * error,release版无效
     *
     * @param tag
     * @param t
     */
    public static void e(String tag, Throwable t)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.e(t);
        }
        else
        {
            Timber.tag(tag).e(t);
        }
    }

    /**
     * error,release版有效,发送远程日志
     *
     * @param module 模块,不能为空
     * @param tag    tag,不能为空
     * @param t      异常
     */
    public static void ee(@NonNull String module, @NonNull String tag, Throwable t)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).e(t);
    }

    /**
     * error,release版无效
     *
     * @param t
     * @param message
     * @param args
     */
    public static void e(Throwable t, String message, Object... args)
    {
        e(getTag(), t, message, args);
    }

    /**
     * error,release版无效
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void e(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.e(t, message, args);
        }
        else
        {
            Timber.tag(tag).e(t, message, args);
        }
    }

    /**
     * error,release版有效,发送远程日志
     *
     * @param module  模块,不能为空
     * @param tag     tag,不能为空
     * @param t       异常
     * @param message 内容
     * @param args    内容格式化参数
     */
    public static void ee(@NonNull String module, @NonNull String tag, Throwable t, String message,
                          Object... args)
    {
        if (!isInited() || TextUtils.isEmpty(module) || TextUtils.isEmpty(tag))
        {
            return;
        }
        Timber.tag(mergeModuleTag(module, tag)).e(t, message, args);
    }

    /**
     * wtf,release版无效
     *
     * @param message
     * @param args
     */
    public static void wtf(String message, Object... args)
    {
        wtf(getTag(), message, args);
    }

    /**
     * wtf,release版无效
     *
     * @param tag
     * @param message
     * @param args
     */
    public static void wtf(String tag, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.wtf(message, args);
        }
        else
        {
            Timber.tag(tag).wtf(message, args);
        }
    }

    /**
     * wtf,release版无效
     *
     * @param t
     */
    public static void wtf(Throwable t)
    {
        wtf(getTag(), t);
    }

    /**
     * wtf,release版无效
     *
     * @param tag
     * @param t
     */
    public static void wtf(String tag, Throwable t)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.wtf(t);
        }
        else
        {
            Timber.tag(tag).wtf(t);
        }
    }

    /**
     * wtf,release版无效
     *
     * @param t
     * @param message
     * @param args
     */
    public static void wtf(Throwable t, String message, Object... args)
    {
        wtf(getTag(), t, message, args);
    }

    /**
     * wtf,release版无效
     *
     * @param tag
     * @param t
     * @param message
     * @param args
     */
    public static void wtf(String tag, Throwable t, String message, Object... args)
    {
        if (!isInited() || isRelease())
        {
            return;
        }
        if (TextUtils.isEmpty(tag))
        {
            Timber.wtf(t, message, args);
        }
        else
        {
            Timber.tag(tag).wtf(t, message, args);
        }
    }
}
