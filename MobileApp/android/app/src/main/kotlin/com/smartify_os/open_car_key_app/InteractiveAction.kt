package com.smartify_os.open_car_key_app

import android.content.Context
import android.net.Uri
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import androidx.core.net.toUri

class InteractiveAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        // Retrieve the string using the key. Provide a default value with "?:"
        val actionType = parameters[ACTION_TYPE_KEY] ?: "unknown_action"

        // Now you can use the actionType to build your Uri or perform logic
        println("Action received: $actionType") // For debugging

        // Pass the dynamic actionType to your Flutter background callback
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            "homeWidget://widget_action?action_type=$actionType".toUri()
        )

        backgroundIntent.send()
    }
}