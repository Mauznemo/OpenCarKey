package com.smartify_os.open_car_key_app

import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService


class AutoLockTileService: TileService() {

    private lateinit var sharedPreferences: SharedPreferences
    companion object {
        var autoLockEnabled: Boolean = false
    }
    override fun onCreate() {
        super.onCreate()
        sharedPreferences = getSharedPreferences("app_prefs", MODE_PRIVATE)
        autoLockEnabled = sharedPreferences.getBoolean("auto_lock_enabled", false)
    }
    override fun onTileAdded() {
        super.onTileAdded()
        // Set the initial state of the tile
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.label = "Proximity Key"
        qsTile.subtitle = "Disabled"
        qsTile.icon = Icon.createWithResource(this, R.drawable.ic_proximity_key)
        qsTile.updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        autoLockEnabled = sharedPreferences.getBoolean("auto_lock_enabled", false)
        qsTile.label = "Proximity Key"
        updateTile(autoLockEnabled)
    }

    override fun onStopListening() {
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()

        autoLockEnabled = !autoLockEnabled

        if(autoLockEnabled)
            EventBus.post("SEND_MESSAGE:al\n")
        else
            EventBus.post("SEND_MESSAGE:ald\n")

        updateTile(autoLockEnabled)

        val editor = sharedPreferences.edit()
        editor.putBoolean("auto_lock_enabled", autoLockEnabled)
        editor.apply()


    }

    private fun updateTile(enabled: Boolean){
        qsTile.state = if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile.subtitle = if (enabled) "Enabled" else "Disabled"

        qsTile.updateTile()
    }
}