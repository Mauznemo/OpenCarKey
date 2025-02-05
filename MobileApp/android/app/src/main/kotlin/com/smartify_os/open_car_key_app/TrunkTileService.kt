package com.smartify_os.open_car_key_app

import android.graphics.drawable.Icon
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class TrunkTileService : TileService() {

    private val eventListener: (String) -> Unit = { event ->
        if (event.startsWith("DEVICE_APPEARED:")) {
            val address = event.substringAfter(":")
            qsTile.subtitle = "Connecting ($address)"
            qsTile.updateTile()
        }
        else if (event.startsWith("DEVICE_CONNECTED:")) {
            qsTile.state = Tile.STATE_INACTIVE
            qsTile.subtitle = "Click to open"
            qsTile.updateTile()
        }
        else if (event.startsWith("DEVICE_DISCONNECTED:")) {
            qsTile.state = Tile.STATE_UNAVAILABLE
            qsTile.subtitle = "Disconnected"
            qsTile.updateTile()
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
        qsTile.label = "Open Trunk"
        qsTile.subtitle = "Disconnected"
        qsTile.icon = Icon.createWithResource(this, R.drawable.ic_open_trunk)
        qsTile.updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        if(CompanionService.connected){
            qsTile.state = Tile.STATE_INACTIVE
            qsTile.subtitle = "Click to open"
            qsTile.updateTile()
            return;
        }
        qsTile.subtitle = "Disconnected"
        qsTile.state = Tile.STATE_UNAVAILABLE
        qsTile.icon = Icon.createWithResource(this, R.drawable.ic_open_trunk)
        qsTile.updateTile()
        // Update the tile state if necessary
    }

    override fun onStopListening() {
        super.onStopListening()
        // Clean up if needed
    }

    override fun onClick() {
        super.onClick()
        // Handle tile click
        Log.d("MyTileService", "Tile clicked!")
        EventBus.post("SEND_MESSAGE:ut\n")

        // Example: Toggle the tile state
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.updateTile()
    }
}
