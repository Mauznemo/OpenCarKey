import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

data class Vehicle(
    val name: String,
    val macAddress: String,
    val associationId: Int,
    val pin: String,
    val hasTrunkUnlocked: Boolean,
    val hasEngineStart: Boolean
)

class VehicleStorage(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()

    fun getVehicles(): List<Vehicle> {
        val json = prefs.getString(KEY_VEHICLES, null) ?: return emptyList()

        // Create type token for List<Vehicle>
        val type = object : TypeToken<List<Vehicle>>() {}.type

        return try {
            gson.fromJson(json, type)
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    fun getVehicleByMac(macAddress: String): Vehicle? {
        return getVehicles().find { vehicle ->
            vehicle.macAddress.equals(macAddress, ignoreCase = true)
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_VEHICLES = "vehicles"
    }
}