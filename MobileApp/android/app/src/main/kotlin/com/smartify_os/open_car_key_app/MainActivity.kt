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
import android.graphics.drawable.Icon
import android.net.MacAddress
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.service.quicksettings.Tile
import android.util.Log
import androidx.core.app.ActivityCompat
import com.smartify_os.open_car_key_app.DoorsTileService.DoorState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.util.concurrent.Executor
import java.util.regex.Pattern

class MainActivity: FlutterActivity(){
    private var bleEventSink: EventChannel.EventSink? = null

    private lateinit var bluetoothAdapter: BluetoothAdapter
    private lateinit var sharedPreferences: SharedPreferences

    private val deviceManager: CompanionDeviceManager by lazy {
        getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
    }

    private val executor: Executor =  Executor { it.run() }

    private val eventListener: (String) -> Unit = { event ->
        runOnUiThread {bleEventSink?.success(event)}
    }

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {

        sharedPreferences = getSharedPreferences("shared_preferences", Context.MODE_PRIVATE)
    }

    override fun onDestroy() {
        super.onDestroy()
        EventBus.unsubscribe(eventListener)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventBus.subscribe(eventListener)

        // Set up EventChannel for BLE Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.smartify_os.open_car_key_app/ble_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bleEventSink = events // Store eventSink for sending events later
                }

                override fun onCancel(arguments: Any?) {
                    bleEventSink = null // Stop sending events when Flutter cancels listening
                }
            }
        )

        // BLE MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.smartify_os.open_car_key_app/ble").setMethodCallHandler { call, result ->
            when (call.method) {
                "associateBle" -> {
                    associateBle(result)
                }
                "disassociateBle" -> {
                    val associationId = call.argument<Int>("associationId")
                    val macAddress = call.argument<String>("macAddress")
                    if (associationId != null && macAddress != null) {
                        disassociateBle(associationId, macAddress)
                        result.success(true)
                    }
                    else result.error("INVALID_VARIABLES", "One or both variables are null", null)

                }
                "getAssociated" -> {
                    result.success(getAssociated())
                }
                "postEvent" -> {
                    val message = call.argument<String>("message")
                    if (message != null) {
                        EventBus.post(message)
                        result.success(true)
                    }
                    else {
                        result.error("INVALID_VARIABLES", "Message is null", null)
                    }
                }
                "getConnectedDevices" -> {
                    result.success(JSONArray(CompanionService.connectedDevices).toString())
                }
                else -> result.notImplemented()
            }
        }
    }


    private fun associateBle(result: MethodChannel.Result) {
        val deviceFilter: BluetoothDeviceFilter = BluetoothDeviceFilter.Builder()
            .build()

        val pairingRequest: AssociationRequest = AssociationRequest.Builder()
            // Find only devices that match this request filter.
            .addDeviceFilter(deviceFilter)
            // Stop scanning as soon as one device matching the filter is found.
            .setSingleDevice(false)
            .build()

        deviceManager.associate(pairingRequest,
            executor,
            object : CompanionDeviceManager.Callback() {
                // Called when a device is found. Launch the IntentSender so the user
                // can select the device they want to pair with.
                override fun onAssociationPending(intentSender: IntentSender) {
                    startIntentSenderForResult(intentSender, 420, null, 0, 0, 0)
                }

                override fun onAssociationCreated(associationInfo: AssociationInfo) {
                    val associationId: Int = associationInfo.id
                    val macAddress: MacAddress? = associationInfo.deviceMacAddress

                    result.success("$macAddress, $associationId")
                }

                override fun onFailure(errorMessage: CharSequence?) {
                    result.error("BLE_ASSOCIATION_FAILED", "$errorMessage", null)
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

                        deviceManager.startObservingDevicePresence(device.address);
                    }
                }
            }
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun disassociateBle(id: Int, macAddress: String) {
        deviceManager.stopObservingDevicePresence(macAddress)
        deviceManager.disassociate(id)
    }

    private fun getAssociated(): String {
        return deviceManager.myAssociations.toString()
    }
}
