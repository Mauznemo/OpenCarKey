package com.smartify_os.open_car_key_app

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.MacAddress
import android.os.Bundle
import android.os.PersistableBundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.regex.Pattern

class MainActivity: FlutterActivity(){
    private val CHANNEL = "com.smartify_os.open_car_key_app/ble"

    private lateinit var bluetoothAdapter: BluetoothAdapter
    private lateinit var sharedPreferences: SharedPreferences
    //private lateinit var deviceManager: CompanionDeviceManager

    private val deviceManager: CompanionDeviceManager by lazy {
        getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
    }

    private val executor: Executor =  Executor { it.run() }

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
        super.onCreate(savedInstanceState, persistentState)

        sharedPreferences = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "associateBle" -> {
                    associateBle()
                    result.success("BLE associated successfully")
                }
                else -> result.notImplemented()
            }
        }
    }

    // Your existing Kotlin method
    private fun associateBle() {
        NotificationHelper.createNotificationChannel(this@MainActivity, "system", "System Notifications",
            "System Notifications", NotificationManager.IMPORTANCE_LOW)
        NotificationHelper.sendNotification(this@MainActivity, "system", "Started association", "Started scanning for BLE devices...",
            1, R.drawable.ic_launcher_foreground)

        val deviceFilter: BluetoothDeviceFilter = BluetoothDeviceFilter.Builder()
            // Match only Bluetooth devices whose name matches the pattern.
            .setNamePattern(Pattern.compile("DSD TECH"))
            .build()

        val pairingRequest: AssociationRequest = AssociationRequest.Builder()
            // Find only devices that match this request filter.
            .addDeviceFilter(deviceFilter)
            // Stop scanning as soon as one device matching the filter is found.
            .setSingleDevice(true)
            .build()

        deviceManager.associate(pairingRequest,
            executor,
            object : CompanionDeviceManager.Callback() {
                // Called when a device is found. Launch the IntentSender so the user
                // can select the device they want to pair with.
                override fun onAssociationPending(intentSender: IntentSender) {
                    NotificationHelper.sendNotification(this@MainActivity, "system", "Association Pending", "Association Pending...",
                        1, R.drawable.ic_launcher_foreground)

                    startIntentSenderForResult(intentSender, 420, null, 0, 0, 0)
                }

                override fun onAssociationCreated(associationInfo: AssociationInfo) {
                    // An association is created.
                    val associationId: Int = associationInfo.id
                    val macAddress: MacAddress? = associationInfo.deviceMacAddress
                    saveAssociationInfo(macAddress)
                    NotificationHelper.sendNotification(this@MainActivity, "system", "Successfully associated ($associationId)", "Successfully associated with $macAddress",
                        1, R.drawable.ic_launcher_foreground)
                }

                override fun onFailure(errorMessage: CharSequence?) {
                    // To handle the failure.
                    NotificationHelper.sendNotification(this@MainActivity, "system", "Association failed", "Failed ($errorMessage)",
                        1, R.drawable.ic_launcher_foreground)
                }

            })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            420 -> when(resultCode) { //Called from associateBle()
                Activity.RESULT_OK -> {
                    // The user chose to pair the app with a Bluetooth device.
                    val deviceToPair: BluetoothDevice? =
                        data?.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE)
                    deviceToPair?.let { device ->
                        if (ActivityCompat.checkSelfPermission(
                                this,
                                Manifest.permission.BLUETOOTH_CONNECT
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            return
                        }
                        //connectToDevice(device)
                        deviceManager.startObservingDevicePresence(device.address);
                        // Maintain continuous interaction with a paired device.
                    }
                }
            }
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun isDeviceAssociated(): Boolean {
        return sharedPreferences.getBoolean("device_associated", false)
    }

    private fun saveAssociationInfo(macAddress: MacAddress?) {
        val editor = sharedPreferences.edit()
        editor.putBoolean("device_associated", true)
        editor.putString("device_mac_address", macAddress.toString())
        editor.apply()
    }
}
