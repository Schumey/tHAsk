package de.schumey.thask

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ThaskWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ThaskWidget>() {
    override val glanceAppWidget = ThaskWidget()
}
