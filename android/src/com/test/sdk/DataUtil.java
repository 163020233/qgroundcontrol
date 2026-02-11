package com.test.sdk;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Author:Xujingtao
 * Date:2025/7/17
 */
public class DataUtil
{

    public static final int NO_GPS = 0;
    public static final int NO_FIX = 1;
    public static final int TYPE_2D = 2;
    public static final int TYPE_3D = 3;
    public static final int TYPE_3D_PLUS = 4;
    public static final int RTK = 5;
    public static final int FLOAT = 6;
    private static volatile DataUtil instance;


    public static DataUtil getInstance()
    {
        if (instance == null)
        {
            synchronized (DataUtil.class)
            {
                if (instance == null)
                {
                    instance = new DataUtil();
                }
            }
        }
        return instance;
    }

    public String getText(byte[] text)
    {
        String result = "";
        for (int i = 0; i < 50; i++)
        {
            if (text[i] == 0)
            {
                break;
            }
            result = result + (char) text[i];
        }
        if (result.contains("\\"))
        {
            result = convertUnicode(result);
        }
        return result;
    }

    private final Pattern pattern = Pattern.compile("(\\\\u(\\p{XDigit}{4}))");


    /**
     * java中unicode和中文相互转换
     */
    public String convertUnicode(String string)
    {
        Matcher matcher = pattern.matcher(string);
        char ch;
        while (matcher.find())
        {
            ch = (char) Integer.parseInt(matcher.group(2), 16);
            string = string.replace(matcher.group(1), ch + "");
        }
        return string;
    }


    public static String getFlightMode(int mode)
    {
        String result;
        switch (mode)
        {
            case 0:
                result = "姿态保持";
                return result;
            case 2:
                result = "高度保持";
                return result;
            case 3:
                result = "自主作业";
                return result;
            case 5:
                result = "位置保持";
                return result;
            case 6:
                result = "返航";
                return result;
            case 9:
                result = "降落";
                return result;
            case 17:
                result = "悬停";
                return result;
            default:
                result = "未知";
                return result;
        }

    }

    public static String getFixType(int type)
    {
        switch (type)
        {
            case NO_GPS:
                return "NO GPS";
            case NO_FIX:
                return "NO FIX";
            case TYPE_2D:
                return "2D";
            case TYPE_3D:
            case TYPE_3D_PLUS:
                return "3D";
            case RTK:
                return "RTK";
            case FLOAT:
                return "FLOAT";
            default:
                return "—";
        }
    }

}
