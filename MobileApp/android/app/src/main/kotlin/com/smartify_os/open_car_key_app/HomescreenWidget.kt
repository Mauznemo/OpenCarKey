package com.smartify_os.open_car_key_app

import androidx.glance.appwidget.GlanceAppWidget
import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.Image
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.components.CircleIconButton
import androidx.glance.appwidget.provideContent
import androidx.glance.color.DynamicThemeColorProviders
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.height
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.size
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
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
        val backgroundServiceEnabled = prefs.getBoolean("backgroundService", true)

        var name = "N/A"
        var macAddress = ""
        var hasEngineStart = false
        var hasTrunkUnlock = false
        var isLocked = false
        var engineOn = false

        if (!backgroundServiceEnabled) {
            Box(modifier = GlanceModifier.fillMaxSize().background(DynamicThemeColorProviders.widgetBackground).padding(16.dp), contentAlignment = Alignment.Center) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Background service is disabled", style = TextStyle(color = DynamicThemeColorProviders.inverseSurface))
                }

            }
            return
        }

        if (currentVehicleJson == "none") {
            Box(modifier = GlanceModifier.fillMaxSize().background(DynamicThemeColorProviders.widgetBackground).padding(16.dp), contentAlignment = Alignment.Center) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(provider = ImageProvider(R.drawable.bluetooth_disabled_24px), contentDescription = "Nothing connected", modifier = GlanceModifier.size(24.dp))
                    Spacer(GlanceModifier.width(10.dp))
                    Text("Nothing connected", style = TextStyle(color = DynamicThemeColorProviders.inverseSurface))
                }

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
                println("Error parsing JSON: ${e.message}")
            }
        }

        Box(modifier = GlanceModifier.fillMaxSize().background(DynamicThemeColorProviders.widgetBackground).padding(
            top = 10.dp,
            start = 15.dp,
            end = 15.dp,
            bottom = 12.dp
        )) {
            Column(
                modifier = GlanceModifier.fillMaxSize()
            ){
                Text(name, style = TextStyle(color = DynamicThemeColorProviders.inverseSurface, fontSize = 18.sp, fontWeight = FontWeight.Bold ))
            Spacer(modifier = GlanceModifier.defaultWeight());

                Row(modifier = GlanceModifier
                    .fillMaxWidth()){
                    CircleIconButton(
                        modifier = GlanceModifier.size(50.dp),
                        imageProvider = ImageProvider(if (isLocked) R.drawable.lock_24px else R.drawable.lock_open_24px),
                        contentDescription = if (isLocked) "Unlock" else "Lock",
                        onClick = actionRunCallback<InteractiveAction>(
                            parameters = actionParametersOf(
                                ACTION_TYPE_KEY to if (isLocked) "unlock" else "lock",
                                MAC_ADDRESS_KEY to macAddress
                            )
                        ),
                        backgroundColor = DynamicThemeColorProviders.primaryContainer,
                        contentColor = DynamicThemeColorProviders.primary

                    )
                    if (hasTrunkUnlock) {
                        Spacer(GlanceModifier.width(16.dp))
                        CircleIconButton(
                            modifier = GlanceModifier.size(50.dp),
                            imageProvider = ImageProvider(R.drawable.directions_car_24px),
                            contentDescription = "Open Trunk",
                            onClick = actionRunCallback<InteractiveAction>(
                                parameters = actionParametersOf(
                                    ACTION_TYPE_KEY to "open_trunk",
                                    MAC_ADDRESS_KEY to macAddress
                                )
                            ),
                            backgroundColor = DynamicThemeColorProviders.primaryContainer,
                            contentColor = DynamicThemeColorProviders.primary
                        )

                    }
                    if (hasEngineStart) {
                        Spacer(GlanceModifier.width(16.dp))
                        CircleIconButton(
                            modifier = GlanceModifier.size(50.dp),
                            imageProvider = ImageProvider(R.drawable.restart_alt_24px),
                            contentDescription = if (engineOn) "Stop Engine" else "Start Engine",
                            onClick = actionRunCallback<InteractiveAction>(
                                parameters = actionParametersOf(
                                    ACTION_TYPE_KEY to "start_engine",
                                    MAC_ADDRESS_KEY to macAddress
                                )
                            ),
                            backgroundColor = DynamicThemeColorProviders.primaryContainer,
                            contentColor = DynamicThemeColorProviders.primary
                        )
                    }
                }
            }}
        }
    }
