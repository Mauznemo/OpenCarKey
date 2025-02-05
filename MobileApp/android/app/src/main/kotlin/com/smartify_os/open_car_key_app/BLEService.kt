package com.smartify_os.open_car_key_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import java.util.UUID


class BLEService : Service() {

    private lateinit var bluetoothLeScanner: BluetoothLeScanner
    private var bluetoothGatt: BluetoothGatt? = null


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i("MyTag", "Staring BT service")
        Toast.makeText(this@BLEService, "Staring BT service", Toast.LENGTH_SHORT).show()
        //startForeground(1, createNotification())
        //startScanning()
        return START_STICKY
    }

    private fun createNotification(): Notification {
        val channelId = "my_channel_id"
        val channelName = "My Channel"
        val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("BLE Service")
            .setContentText("Scanning for BLE devices")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .build()
    }

    private  fun observingDevicePresence(){

    }

    private fun startScanning() {

        NotificationHelper.createNotificationChannel(
            this@BLEService, "system", "System Notifications",
            "System Notifications", NotificationManager.IMPORTANCE_LOW
        )
        NotificationHelper.sendNotification(
            this@BLEService, "system", "Started Scanning", "Started scanning for BLE devices...",
            1, R.drawable.ic_launcher_foreground
        )


        bluetoothLeScanner = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter.bluetoothLeScanner
        val leScanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device
                if (ActivityCompat.checkSelfPermission(
                        this@BLEService,
                        Manifest.permission.BLUETOOTH_CONNECT
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Error:", "No BT connect perms",
                        500, R.drawable.ic_launcher_foreground
                    )
                    return
                }

                if (device.name != null) {
                    if(isDeviceConnected(device) || device.name != "DSD TECH")
                    {
                        NotificationHelper.sendNotification(
                            this@BLEService,
                            "system",
                            "Found Device (" + device.name + ")",
                            "But is already connected or wrong name",
                            2,
                            R.drawable.ic_launcher_foreground
                        )
                        return
                    }

                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Found Device", "Connecting...",
                        2, R.drawable.ic_launcher_foreground
                    )
                    connectToDevice(device)
                }
            }
        }
        if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        bluetoothLeScanner.startScan(leScanCallback)
    }

    private fun connectToDevice(device: BluetoothDevice) {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            // TODO: Consider calling
            //    ActivityCompat#requestPermissions
            Log.i("MyTag", "No BT connect perms")
            return
        }
        bluetoothGatt = device.connectGatt(this, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothAdapter.STATE_CONNECTED) {

                    if (ActivityCompat.checkSelfPermission(
                            this@BLEService,
                            Manifest.permission.BLUETOOTH_CONNECT
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        Toast.makeText(this@BLEService, "No Bluetooth connect permission", Toast.LENGTH_SHORT).show()
                        return
                    }

                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Connected", "Connected to HM-10",
                        3, R.drawable.ic_launcher_foreground
                    )

                    gatt.discoverServices()
                } else if (newState == BluetoothAdapter.STATE_DISCONNECTED) {
                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Disconnected", "Disconnected from HM-10",
                        3, R.drawable.ic_launcher_foreground
                    )
                    // Reconnect if necessary
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    // Handle the services discovered
                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Ready", "HM-10 Ready to use",
                        3, R.drawable.ic_launcher_foreground
                    )

                    val serviceUUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
                    // Use the HM-10 Characteristic UUID
                    val characteristicUUID = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")

                    val service = gatt.getService(serviceUUID)
                    val characteristic = service?.getCharacteristic(characteristicUUID)

                    if (characteristic != null) {
                        // Write to the characteristic
                        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.TIRAMISU)
                        {
                            val handler = Handler(Looper.getMainLooper())
                            val delayMillis = 10000L // 1 second delay

                            val runnable = object : Runnable {
                                override fun run() {
                                    // Your repeated task here
                                    sendDataToCharacteristic(gatt, characteristic, "Your data to send\n")

                                    // Repeat this runnable again after the delay
                                    handler.postDelayed(this, delayMillis)
                                }
                            }

                            // Start the loop
                            handler.post(runnable)

                        }
                    } else {
                        NotificationHelper.sendNotification(
                            this@BLEService,
                            "system",
                            "Characteristic not found",
                            "HM-10 Characteristic not found",
                            4,
                            R.drawable.ic_launcher_foreground
                        )
                    }
                }
            }

            @RequiresApi(Build.VERSION_CODES.TIRAMISU)
            private fun sendDataToCharacteristic(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, data: String) {
                // Convert your data to bytes
                val dataBytes = data.toByteArray()

                // Set the value for the characteristic
                //characteristic.value = dataBytes

                // Write the characteristic
                if (ActivityCompat.checkSelfPermission(
                        this@BLEService,
                        Manifest.permission.BLUETOOTH_CONNECT
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    return
                }
                val success = gatt.writeCharacteristic(characteristic, dataBytes, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
                if (success == BluetoothStatusCodes.SUCCESS) {
                    NotificationHelper.sendNotification(
                        this@BLEService,
                        "system",
                        "Data sent successfully",
                        "HM-10 Data sent successfully",
                        4,
                        R.drawable.ic_launcher_foreground
                    )
                } else {
                    NotificationHelper.sendNotification(
                        this@BLEService, "system", "Failed to send data",
                        "HM-10 Failed to send data ($success)",
                        4, R.drawable.ic_launcher_foreground
                    )
                }
            }
        })
    }

    private fun isDeviceConnected(device: BluetoothDevice): Boolean {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) != PackageManager.PERMISSION_GRANTED
        ) {

            return false
        }

        val connectedDevices = bluetoothManager.getConnectedDevices(BluetoothProfile.GATT)

        // Check if the device is in the list of connected devices
        return connectedDevices.any { it.address == device.address }
    }

    override fun onBind(intent: Intent): IBinder? {
        Log.i("MyTag", "OnBind")
        return null
    }
}
