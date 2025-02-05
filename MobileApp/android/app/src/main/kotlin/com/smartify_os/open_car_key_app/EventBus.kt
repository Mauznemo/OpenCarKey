package com.smartify_os.open_car_key_app

object EventBus {
    private val listeners = mutableListOf<(String) -> Unit>()

    fun subscribe(listener: (String) -> Unit) {
        listeners.add(listener)
    }

    fun unsubscribe(listener: (String) -> Unit) {
        listeners.remove(listener)
    }

    fun post(event: String) {
        listeners.forEach { it(event) }
    }
}