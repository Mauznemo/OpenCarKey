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
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

val ACTION_TYPE_KEY = ActionParameters.Key<String>("action_type_key")

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
        val connectedVehicles = prefs.getString("test", "None")
        Box(modifier = GlanceModifier.background(DynamicThemeColorProviders.primaryContainer).padding(16.dp)) {
            Column() {
                Text(connectedVehicles ?: "None", style = TextStyle(color = ColorProvider(Color.White)))
                Button(
                    text = "Activate",
                    onClick = actionRunCallback<InteractiveAction>(
                        parameters = actionParametersOf(
                            ACTION_TYPE_KEY to "test" // Attach a different parameter
                        )
                    )
                )
            }
        }
    }
}