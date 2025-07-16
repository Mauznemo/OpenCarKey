package com.smartify_os.open_car_key_app

import androidx.glance.appwidget.GlanceAppWidget
import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.Button
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.color.DynamicThemeColorProviders
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.height
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import org.json.JSONObject

val ACTION_TYPE_KEY = ActionParameters.Key<String>("action_type_key")
val MAC_ADDRESS_KEY = ActionParameters.Key<String>("mac_address_key")

class HomescreenWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        val currentVehicleJson = prefs.getString("currentVehicle", "none")

        var name = "N/A"
        var macAddress = ""
        var hasEngineStart = false
        var hasTrunkUnlock = false
        var isLocked = false
        var engineOn = false

        if (currentVehicleJson == "none") {
            Box(modifier = GlanceModifier.fillMaxSize().background(DynamicThemeColorProviders.primaryContainer).padding(16.dp), contentAlignment = Alignment.Center) {
                Text("No vehicle connected, go near one!", style = TextStyle(color = ColorProvider(Color.White)))
            }
            return
        }

        if (currentVehicleJson?.isNotEmpty() == true && currentVehicleJson != "none") {
            try {
                val json = JSONObject(currentVehicleJson ?: "")
                name = json.optString("name", "N/A")
                macAddress = json.optString("macAddress", "")
                hasEngineStart = json.optBoolean("hasEngineStart", false)
                hasTrunkUnlock = json.optBoolean("hasTrunkUnlock", false)
                isLocked = json.optBoolean("isLocked", false)
                engineOn = json.optBoolean("engineOn", false)
            } catch (e: Exception) {
                // Handle JSON parsing error, e.g., log it or use default values
            }
        }

        Box(modifier = GlanceModifier.fillMaxSize().background(DynamicThemeColorProviders.primaryContainer).padding(16.dp)) {
            Column() {
                Text(name, style = TextStyle(color = ColorProvider(Color.White)))
                Spacer(GlanceModifier.height(16.dp))
                Row(){
                    Button(
                        text = if (isLocked) "Unlock" else "Lock",
                        onClick = actionRunCallback<InteractiveAction>(
                            parameters = actionParametersOf(
                                ACTION_TYPE_KEY to if (isLocked) "unlock" else "lock",
                                MAC_ADDRESS_KEY to macAddress
                            )
                        )
                    )
                    if (hasTrunkUnlock) {
                        Spacer(GlanceModifier.width(16.dp))
                        Button(
                            text = "Open Trunk",
                            onClick = actionRunCallback<InteractiveAction>(
                                parameters = actionParametersOf(
                                    ACTION_TYPE_KEY to "open_trunk",
                                    MAC_ADDRESS_KEY to macAddress
                                )
                            )
                        )

                    }
                    if (hasEngineStart) {
                        Spacer(GlanceModifier.width(16.dp))
                        Button(
                            text = if (engineOn) "Stop Engine" else "Start Engine",
                            onClick = actionRunCallback<InteractiveAction>(
                                parameters = actionParametersOf(
                                    ACTION_TYPE_KEY to "start_engine",
                                    MAC_ADDRESS_KEY to macAddress
                                )
                            )
                        )
                    }
                }
            }
        }
    }
}