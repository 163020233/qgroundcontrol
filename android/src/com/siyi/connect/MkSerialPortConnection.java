package com.siyi.connect;

import android.serialport.SerialPort;
import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 硬件串口连接
 */
public class MkSerialPortConnection {

    //串口实例
    public SerialPort mSerialPort;

    //波特率
    private int baudrate;
    //path
    private String path;
    //标志
    private int flags;
    //校验位
    private int parity;
    //数据位
    private int dataBits;
    //停止位
    private int stopBits;
    //流控
    private int flowCon;
    //驱动缓冲区大小 默认-1
    private int fifoSize;
    private int readSize = 2048;

    public InputStream inputStream;

    public OutputStream outputStream;

    private Lock lock;

    private Condition notEntry;

    private Condition notFull;

    private List<byte[]> messageQueue;

    //连接状态
    private volatile boolean connect;

    //发送线程
    private ForwardThread mForwardThread;
    //读取线程
    private ReadThread mReadThread;

    private MkSerialPortConnection(String path, int baudrate, int dataBits, int parity, int stopBits, int flowCon, int fifoSize, int readSize, int flags) {
        this.path = path;
        this.baudrate = baudrate;
        this.dataBits = dataBits;
        this.stopBits = stopBits;
        this.parity = parity;
        this.flags = flags;
        this.flowCon = flowCon;
        this.fifoSize = fifoSize;
        this.readSize = readSize;
    }

    /**
     * 打开串口
     *
     * @throws IOException
     */
    public void openConnection() throws Exception {
        mSerialPort = SerialPort.newBuilder(path, baudrate)
                .flags(flags)
                .parity(parity)
                .dataBits(dataBits)
                .stopBits(stopBits)
                .flowCon(flowCon)
                .fifoSize(fifoSize)
                .build();
        inputStream = mSerialPort.getInputStream();
        outputStream = mSerialPort.getOutputStream();

        connect = true;

        //开启发送数据线程
        messageQueue = new ArrayList<>();
        mForwardThread = new ForwardThread();
        mForwardThread.start();

        //开启读取
        if (inputStream != null) {
            mReadThread = new ReadThread();
            mReadThread.start();
        }

        if (delegate != null) {
            delegate.onConnected();
        }
    }

    /**
     * 关闭串口
     *
     * @throws IOException
     */
    public void closeConnection() throws IOException {
        connect = false;

        delegate = null;

        //关闭消息轮训
        if (mForwardThread != null) {
            mForwardThread.interrupt();
            mForwardThread = null;
        }
        //清空消息队列
        if (messageQueue != null) {
            messageQueue.clear();
            messageQueue = null;
        }
        //关闭读取线程
        if (mReadThread != null) {
            mReadThread.interrupt();
            mReadThread = null;
        }
        //关闭输入输出流
        if (outputStream != null) {
            outputStream.close();
            outputStream = null;
        }
        if (inputStream != null) {
            inputStream.close();
            inputStream = null;
        }

        //关闭串口
        if (mSerialPort != null) {
            mSerialPort.close();
            mSerialPort = null;
        }
    }

    public void connect_device() throws Exception {
        mSerialPort = SerialPort.newBuilder(path, baudrate)
                .flags(flags)
                .parity(parity)
                .dataBits(dataBits)
                .stopBits(stopBits)
                .flowCon(flowCon)
                .fifoSize(fifoSize)
                .build();
//        inputStream = mSerialPort.getInputStream();
//        outputStream = mSerialPort.getOutputStream();
        connect = true;
//        //开启发送数据线程
//        messageQueue = new ArrayList();
//        mForwardThread = new ForwardThread();
//        mForwardThread.start();
//
//        //开启读取
//        if (inputStream != null) {
//            mReadThread = new ReadThread();
//            mReadThread.start();
//        }
//
//        if(delegate != null){
//            delegate.connect();
//        }
    }

    /**
     * 发送方法
     * 将消息加入到队列 等待发送
     *
     * @param bytes
     */
    public void sendData(final byte[] bytes) {
        if (bytes == null || !connect || lock == null) {
            return;
        }

        new Runnable() {
            @Override
            public void run() {
                boolean flag = true;
                try {
                    lock.lock();
                    messageQueue.add(bytes);
                    notEntry.signalAll();
                } catch (Exception e) {
                    flag = false;
                } finally {
                    if (flag) {
                        lock.unlock();
                    }
                }
            }
        }.run();
    }

    /**
     * 发送线程
     */
    class ForwardThread extends Thread {
        @Override
        public void run() {
            lock = new ReentrantLock();
            notEntry = lock.newCondition();
            notFull = lock.newCondition();
            while (!isInterrupted()) {
                next();
            }
        }
    }

    /**
     * 轮询
     */
    private  void next() {
        try {
            lock.lock();
            if (!connect) {
                try {
                    notEntry.await();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                return;
            }

            if (messageQueue == null || messageQueue.isEmpty()) {
                try {
                    notEntry.await();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                return;
            }

            byte[] message = messageQueue.get(0);

            try {
                if (outputStream != null && message != null) {
                    outputStream.write(message);
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
            messageQueue.remove(0);
            notFull.signalAll();

        } finally {
            lock.unlock();
        }
    }

    /**
     * 读取线程
     */
    class ReadThread extends Thread {
        @Override
        public void run() {
            byte[] buffer = new byte[readSize];
            int size = 0;
            while (!isInterrupted()) {
                try {
                    if (inputStream == null) {
                        return;
                    }

                    size = inputStream.read(buffer);
                    Log.i("SerialPort", "---locker port------读取中" + size);
                    if (size > 0) {
                        received(buffer, size);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    /**
     * 读取回调方法
     */
    private void received(byte[] bytes, int size) {
        if (delegate != null) {
            delegate.received(bytes, size);
        }
    }

    /**
     * 获取连接状态
     *
     * @return
     */
    public boolean isConnection() {
        return connect;
    }

    public interface Delegate {
        void received(byte[] bytes, int size);

        void onConnected();
    }

    private Delegate delegate;

    public void setDelegate(Delegate delegate) {
        this.delegate = delegate;
    }

    public static Builder newBuilder(String devicePath, int baudrate) {
        return new Builder(devicePath, baudrate);
    }

    public final static class Builder {

        private String path;
        private int baudrate;
        private int dataBits = 8;
        private int parity = 0;
        private int stopBits = 1;
        private int flags = 0;
        private int flowCon = 0;
        private int fifoSize = -1;
        private int readSize = 2048;

        private Builder(String path, int baudrate) {
            this.path = path;
            this.baudrate = baudrate;
        }

        /**
         * 数据位
         *
         * @param dataBits 默认8,可选值为5~8
         * @return
         */
        public Builder dataBits(int dataBits) {
            this.dataBits = dataBits;
            return this;
        }

        /**
         * 校验位
         *
         * @param parity 0:无校验位(NONE，默认)；1:奇校验位(ODD);2:偶校验位(EVEN)
         * @return
         */
        public Builder parity(int parity) {
            this.parity = parity;
            return this;
        }

        /**
         * 停止位
         *
         * @param stopBits 默认1；1:1位停止位；2:2位停止位
         * @return
         */
        public Builder stopBits(int stopBits) {
            this.stopBits = stopBits;
            return this;
        }

        /**
         * 标志
         *
         * @param flags 默认0
         * @return
         */
        public Builder flags(int flags) {
            this.flags = flags;
            return this;
        }

        /**
         * 流控
         *
         * @param flowCon 默认0; 0:不使用流控 1：开启硬件流控 2：开启软件流控
         * @return
         */
        public Builder flowCon(int flowCon) {
            this.flowCon = flowCon;
            return this;
        }

        /**
         * 驱动缓存大小
         *
         * @param fifoSize 默认-1； -1 使用驱动默认值
         * @return
         */
        public Builder fifoSize(int fifoSize) {
            this.fifoSize = fifoSize;
            return this;
        }

        /**
         * 读取线程缓冲区大小 默认 2048
         *
         * @param readSize
         * @return
         */
        public Builder readSize(int readSize) {
            this.readSize = readSize;
            return this;
        }

        /**
         * 打开并返回串口
         *
         * @return
         * @throws SecurityException
         * @throws IOException
         */
        public MkSerialPortConnection build() {
            return new MkSerialPortConnection(path, baudrate, dataBits, parity, stopBits, flowCon, fifoSize, readSize, flags);
        }
    }
}
