package com.smartify_os.open_car_key_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import java.util.UUID

class CompanionService: CompanionDeviceService() {

    private lateinit var writeCharacteristic: BluetoothGattCharacteristic
    private lateinit var gatt: BluetoothGatt
    companion object {
        var connected: Boolean = false
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        Log.d("CompanionService", "onDeviceAppeared called")

        if(connected){
            return
        }
        EventBus.post("DEVICE_APPEARED:${associationInfo.deviceMacAddress}")

        connectToDevice(associationInfo.associatedDevice?.bluetoothDevice)
    }

    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
        Log.d("CompanionService", "onDeviceDisappeared called")
    }

    private fun connectToDevice(device: BluetoothDevice?) {
        val sharedPreferences = getSharedPreferences("app_prefs", MODE_PRIVATE)

        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            EventBus.post("CONNECT_FAILED:No permission")
            return
        }

        var bluetoothGatt = device?.connectGatt(this, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothAdapter.STATE_CONNECTED) {

                    if (ActivityCompat.checkSelfPermission(
                            this@CompanionService,
                            Manifest.permission.BLUETOOTH_CONNECT
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        EventBus.post("CONNECT_FAILED:No permission")
                        return
                    }

                    connected = true
                    EventBus.post("DEVICE_CONNECTED:${device.address}")

                    gatt.discoverServices()
                } else if (newState == BluetoothAdapter.STATE_DISCONNECTED) {
                    connected = false
                    EventBus.post("DEVICE_DISCONNECTED:${device.address}")
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    this@CompanionService.gatt = gatt
                    // Handle the services discovered
                    EventBus.post("DEVICE_READY:${device.address}")

                    val serviceUUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
                    val characteristicUUID = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
                    val CHARACTERISTIC_UPDATE_NOTIFICATION_DESCRIPTOR_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

                    val service = gatt.getService(serviceUUID)
                    writeCharacteristic = service?.getCharacteristic(characteristicUUID)!!


                    if (ActivityCompat.checkSelfPermission(
                            this@CompanionService,
                            Manifest.permission.BLUETOOTH_CONNECT
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        EventBus.post("CONNECT_FAILED:No permission")
                        return
                    }

                    gatt.setCharacteristicNotification(writeCharacteristic, true)

                    val descriptor = writeCharacteristic.getDescriptor(CHARACTERISTIC_UPDATE_NOTIFICATION_DESCRIPTOR_UUID)
                    descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    // Enable notifications in the descriptor
                    gatt.writeDescriptor(descriptor)


                    val handler = Handler(Looper.getMainLooper())
                    handler.postDelayed({
                        if(sharedPreferences.getBoolean("auto_lock_enabled", false)){
                            sendString("al\n")
                        }
                    }, 300)

                    handler.postDelayed({
                        if(sharedPreferences.getBoolean("auto_lock_enabled", false)){
                            sendString("al\n")
                        }
                    }, 1000)
                    //sendString("Hello World!\n")
                }
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val receivedData = characteristic.value
                var message = String(receivedData)
                message = message.trim()
                // Process the received message
                Log.d("BLE", "Received message: $message")
                EventBus.post("MESSAGE_RECEIVED:$message;${device.address}")
            }
        })
    }

    fun sendString(message: String) {
        if (::writeCharacteristic.isInitialized) {
            Log.d("BLE", "Sent message: $message")
            val messageBytes = message.toByteArray()
            writeCharacteristic.value = messageBytes
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.BLUETOOTH_CONNECT
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            val success = gatt.writeCharacteristic(writeCharacteristic)

            if (success) {
                EventBus.post("SUCCESSFULLY_SENT:$message")
            } else {
                EventBus.post("FAILED_TO_SEND:$message")
            }
        }
    }

    private val eventListener: (String) -> Unit = { event ->
        if (event.startsWith("SEND_MESSAGE:")) {
            val message = event.substringAfter(":")
            if(connected)
            {
                sendString(message)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        EventBus.subscribe(eventListener)
    }

    override fun onDestroy() {
        super.onDestroy()
        EventBus.unsubscribe(eventListener)
    }
}

