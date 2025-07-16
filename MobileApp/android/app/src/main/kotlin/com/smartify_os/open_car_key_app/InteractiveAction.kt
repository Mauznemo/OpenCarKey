package com.smartify_os.open_car_key_app

import android.content.Context
import android.net.Uri
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class InteractiveAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("homeWidget://titleClicked"))
        backgroundIntent.send()
    }
}
