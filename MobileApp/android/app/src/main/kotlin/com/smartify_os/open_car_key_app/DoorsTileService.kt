package com.smartify_os.open_car_key_app

import android.graphics.drawable.Icon
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class DoorsTileService : TileService() {

    private var doorState: DoorState = DoorState.Unknown

    private val eventListener: (String) -> Unit = { event ->
        if (event.startsWith("DEVICE_APPEARED:")) {
            val address = event.substringAfter(":")
            qsTile.label = "Loading..."
            qsTile.subtitle = "Connecting ($address)"
            qsTile.updateTile()
        }
        else if (event.startsWith("DEVICE_CONNECTED:")) {
            val address = event.substringAfter(":")
            qsTile.label = "Loading..."
            qsTile.state = Tile.STATE_INACTIVE
            qsTile.subtitle = "Connected"
            qsTile.updateTile()

            val handler = Handler(Looper.getMainLooper())
            handler.postDelayed({
                EventBus.post("SEND_MESSAGE:ds\n")
            }, 1000)
        }
        else if (event.startsWith("DEVICE_DISCONNECTED:")) {
            qsTile.state = Tile.STATE_UNAVAILABLE
            qsTile.subtitle = "Disconnected"
            qsTile.updateTile()
        }
        else if (event.startsWith("MESSAGE_RECEIVED:")) {
            val message = event.substringAfter(":")
            if(message == "ud"){
                Log.d("MyTileService", "Received Doors unlocked")
                qsTile.label = "Unlocked"
                qsTile.state = Tile.STATE_INACTIVE
                qsTile.icon = Icon.createWithResource(this, R.drawable.ic_unlocked)
                qsTile.subtitle = "Doors are unlocked"
                qsTile.updateTile()
                doorState = DoorState.Unlocked
            } else if(message == "ld"){
                Log.d("MyTileService", "Received Doors locked")
                qsTile.label = "Locked"
                qsTile.state = Tile.STATE_ACTIVE
                qsTile.icon = Icon.createWithResource(this, R.drawable.ic_locked)
                qsTile.subtitle = "Doors are locked"
                qsTile.updateTile()
                doorState = DoorState.Locked
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

    override fun onTileAdded() {
        super.onTileAdded()
        // Set the initial state of the tile
        qsTile.state = Tile.STATE_UNAVAILABLE
        qsTile.label = "Unknown"
        qsTile.subtitle = "Not connected"
        qsTile.icon = Icon.createWithResource(this, R.drawable.ic_locked)
        qsTile.updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        if(CompanionService.connected){
            EventBus.post("SEND_MESSAGE:ds\n") //Request door state
            return;
        }
        qsTile.subtitle = "Disconnected"
        qsTile.state = Tile.STATE_UNAVAILABLE
        qsTile.updateTile()
    }

    override fun onStopListening() {
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        // Handle tile click
        Log.d("MyTileService", "Tile clicked!")

        // Example: Toggle the tile state
        qsTile.state = if (qsTile.state == Tile.STATE_ACTIVE) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        qsTile.icon = if (qsTile.state == Tile.STATE_ACTIVE) Icon.createWithResource(this, R.drawable.ic_locked)
            else Icon.createWithResource(this, R.drawable.ic_unlocked)
        if (doorState == DoorState.Unlocked)
        {
            EventBus.post("SEND_MESSAGE:ld\n")
        }
        else if (doorState == DoorState.Locked){
            EventBus.post("SEND_MESSAGE:ud\n")
        }
        else{
            EventBus.post("SEND_MESSAGE:ds\n")
        }
        qsTile.updateTile()
    }

    companion object {
        private const val ACTION_UPDATE_TILE = "com.smartify_os.ACTION_UPDATE_TILE"
    }

    enum class DoorState
    {
        Unknown,
        Locked,
        Unlocked
    }
}
