#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "bluetooth.h"
#include "esp_gap_ble_api.h"
#include <mbedtls/sha256.h>
#include <mbedtls/md.h>
#include <nvs.h>
#include <SPIFFS.h>
#include <config.h>
#include <OckAuth.h>
#include <OckCommandProcessor.h>
#include <OckPasswordPolicy.h>
#include <OckProtocol.h>
#include <OckProximity.h>

static_assert(ock::isPasswordLongEnough(PASSWORD),
              "PASSWORD in config.h must be at least 12 characters long. Anyone in Bluetooth range can "
              "record a command and try to guess the password offline, so pick something long and unique.");

#define BLE_MTU_SIZE 64
// BLE service and characteristic UUIDs
#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

const std::string PROTOCOL_VERSION = ock::PROTOCOL_VERSION;

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
esp_bd_addr_t peerAddress;

void (*onConnected)() = nullptr;
void (*onDisconnected)() = nullptr;
void (*onLocked)(bool proximity) = nullptr;
void (*onUnlocked)(bool proximity) = nullptr;
void (*onTrunkOpened)() = nullptr;
void (*onEngineStarted)() = nullptr;
void (*onEngineStopped)() = nullptr;
void (*onWindowsOpened)() = nullptr;
void (*onWindowsClosed)() = nullptr;

bool isLocked = true;
// Engine and window state are only kept in RAM, so they reset to their safe
// defaults on reboot (the app re-reads them with GET_DATA on every connect).
bool engineOn = false;
bool windowsOpen = false;
bool deviceConnected = false;
bool autoLocking = false;

bool oldDeviceConnected = false;

// Delayed low-power connection parameter request. Armed in onConnect and fired
// ~5s later from bluetoothLoop so it doesn't race Android's service discovery /
// MTU exchange or slow the initial GET_VERSION/GET_FEATURES/GET_DATA burst.
unsigned long connParamUpdateAt = 0;
bool connParamsPending = false;

const int bootButtonPin = 0;
unsigned long bootButtonPressStart = 0;
bool isBootButtonPressed = false;
bool counterResetDone = false;

float triggerRssiStrength = 0;
float releaseRssiStrength = 0;
int rssiDeadZone = 4;
ock::RssiFilter rssiFilter;
unsigned long previousRssiMillis = 0;
const long rssiInterval = 500;
bool sendRssi = false;
float proximityCooldown = 1; // in min
unsigned long previousProximityMillis = 0;

namespace
{
    const char *NVS_NAMESPACE = "ock";
    const char *NVS_COUNTER_KEY = "counter";
    const char *LEGACY_COUNTER_FILE = "/counter";

    bool hmacSha256(const uint8_t *key, size_t keyLength, const uint8_t *message, size_t messageLength, uint8_t *out)
    {
        const mbedtls_md_info_t *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
        return info != nullptr && mbedtls_md_hmac(info, key, keyLength, message, messageLength, out) == 0;
    }

    /// Stores the rolling code counter in NVS. NVS writes are power-loss safe (the old value
    /// stays valid until the new one is fully written) and wear leveled, so a brown-out while
    /// cranking the engine can't reset the counter to 0 and make recorded commands valid again.
    class NvsCounterStore : public ock::CounterStore
    {
    public:
        bool load(uint32_t &counter) override
        {
            uint32_t stored = 0;
            if (!readNvs(stored))
                return false;

            // Counters used to be kept in a SPIFFS file, carry them over so an update
            // doesn't start from 0 again.
            uint32_t legacy = 0;
            if (readLegacyCounter(legacy))
            {
                if (legacy > stored)
                {
                    if (!save(legacy))
                        return false;
                    stored = legacy;
                }
                SPIFFS.remove(LEGACY_COUNTER_FILE);
                SPIFFS.end();
            }

            counter = stored;
            return true;
        }

        bool save(uint32_t counter) override
        {
            nvs_handle_t handle;
            if (nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle) != ESP_OK)
                return false;
            const bool ok = nvs_set_u32(handle, NVS_COUNTER_KEY, counter) == ESP_OK && nvs_commit(handle) == ESP_OK;
            nvs_close(handle);
            return ok;
        }

    private:
        bool readNvs(uint32_t &counter)
        {
            nvs_handle_t handle;
            if (nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle) != ESP_OK)
                return false;
            const esp_err_t err = nvs_get_u32(handle, NVS_COUNTER_KEY, &counter);
            nvs_close(handle);

            if (err == ESP_ERR_NVS_NOT_FOUND)
            {
                counter = 0;
                return true;
            }
            return err == ESP_OK;
        }

        /// Leaves SPIFFS mounted if the file exists, so load() can remove it
        bool readLegacyCounter(uint32_t &counter)
        {
            if (!SPIFFS.begin(false))
                return false;
            if (!SPIFFS.exists(LEGACY_COUNTER_FILE))
            {
                SPIFFS.end();
                return false;
            }

            File file = SPIFFS.open(LEGACY_COUNTER_FILE, "r");
            String content = file ? file.readString() : String();
            file.close();

            char *end = nullptr;
            const unsigned long value = strtoul(content.c_str(), &end, 10);
            counter = (end != content.c_str()) ? static_cast<uint32_t>(value) : 0;
            return true;
        }
    };

    NvsCounterStore counterStore;
    ock::RollingCodeVerifier verifier(hmacSha256, counterStore);
}

void sendToClient(Esp32Response responseCode, const uint8_t *data = nullptr, size_t dataLen = 0)
{
    if (dataLen > 12)
    {
        Serial.println("Warning: data truncated to 12 bytes.");
        dataLen = 12;
    }

    size_t totalBufferSize = 1 + (dataLen > 0 ? 1 + dataLen : 0);
    std::vector<uint8_t> responseBuffer(totalBufferSize);

    responseBuffer[0] = static_cast<uint8_t>(responseCode);

    if (DEBUG_MODE)
        Serial.printf("Sent ESP32 Response: 0x%02X\n", static_cast<uint8_t>(responseCode));

    if (dataLen > 0)
    {
        responseBuffer[1] = static_cast<uint8_t>(dataLen);
        memcpy(responseBuffer.data() + 2, data, dataLen);

        if (DEBUG_MODE)
            Serial.printf(", Data Length: %zu\n", dataLen);
    }

    pCharacteristic->setValue(responseBuffer.data(), totalBufferSize);
    pCharacteristic->notify();
}

void sendToClientFloat(Esp32Response responseCode, float value)
{
    sendToClient(responseCode, reinterpret_cast<const uint8_t *>(&value), sizeof(float));
}

void sendToClientInt32(Esp32Response responseCode, int32_t value)
{
    sendToClient(responseCode, reinterpret_cast<const uint8_t *>(&value), sizeof(int32_t));
}

void sendToClientString(Esp32Response responseCode, const std::string &str)
{
    sendToClient(responseCode, reinterpret_cast<const uint8_t *>(str.c_str()), str.length());
}

namespace
{
    void lock(bool proximity = false, bool ignoreCooldown = false)
    {
        if (proximity && !ignoreCooldown &&
            ock::proximityCooldownActive(millis(), previousProximityMillis, proximityCooldown))
        {
            return;
        }

        if (proximity)
            previousProximityMillis = millis();

        if (deviceConnected)
        {
            sendToClient(proximity ? Esp32Response::PROXIMITY_LOCKED : Esp32Response::LOCKED);
        }

        isLocked = true;

        if (onLocked)
            onLocked(proximity);

        if (DEBUG_MODE)
            Serial.println("Locked (proximity:" + String(proximity) + ")");
    }

    void unlock(bool proximity = false, bool ignoreCooldown = false)
    {
        if (proximity && !ignoreCooldown &&
            ock::proximityCooldownActive(millis(), previousProximityMillis, proximityCooldown))
        {
            return;
        }

        if (proximity)
            previousProximityMillis = millis();

        if (deviceConnected)
        {
            sendToClient(proximity ? Esp32Response::PROXIMITY_UNLOCKED : Esp32Response::UNLOCKED);
        }

        isLocked = false;

        if (onUnlocked)
            onUnlocked(proximity);

        if (DEBUG_MODE)
            Serial.println("Unlocked (proximity:" + String(proximity) + ")");
    }

    void openTrunk()
    {
        if (onTrunkOpened)
            onTrunkOpened();
    }

    void startEngine()
    {
        if (deviceConnected)
            sendToClient(Esp32Response::ENGINE_STARTED);

        engineOn = true;

        if (onEngineStarted)
            onEngineStarted();

        if (DEBUG_MODE)
            Serial.println("Engine started");
    }

    void stopEngine()
    {
        if (deviceConnected)
            sendToClient(Esp32Response::ENGINE_STOPPED);

        engineOn = false;

        if (onEngineStopped)
            onEngineStopped();

        if (DEBUG_MODE)
            Serial.println("Engine stopped");
    }

    void openWindows()
    {
        if (deviceConnected)
            sendToClient(Esp32Response::WINDOWS_OPENED);

        windowsOpen = true;

        if (onWindowsOpened)
            onWindowsOpened();

        if (DEBUG_MODE)
            Serial.println("Windows opened");
    }

    void closeWindows()
    {
        if (deviceConnected)
            sendToClient(Esp32Response::WINDOWS_CLOSED);

        windowsOpen = false;

        if (onWindowsClosed)
            onWindowsClosed();

        if (DEBUG_MODE)
            Serial.println("Windows closed");
    }

    void enableProxKey()
    {
        // Readings taken while the proximity key was off can be from somewhere else entirely
        rssiFilter.reset();
        autoLocking = true;
    }

    void disableProxKey()
    {
        autoLocking = false;
    }
}

class MyServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer, esp_ble_gatts_cb_param_t *param)
    {
        if (DEBUG_MODE)
            Serial.println("Connected");
        memcpy(peerAddress, param->connect.remote_bda, sizeof(esp_bd_addr_t));
        // Readings from the previous connection must never count for this one
        rssiFilter.reset();
        deviceConnected = true;

        // Request low-power connection parameters, but delayed (see bluetoothLoop).
        connParamUpdateAt = millis() + 5000;
        connParamsPending = true;

        if (onConnected)
            onConnected();
    };

    void onDisconnect(BLEServer *pServer)
    {
        if (DEBUG_MODE)
            Serial.println("Disconnected");
        deviceConnected = false;
        rssiFilter.reset();
        // Cancel any pending conn-param update so it can't fire against a new peer.
        connParamsPending = false;
        if (autoLocking && !isLocked) // Only true if disconnected before auto locking
        {
            // Possible edge case when proximity key is set to connection range and it connects, unlocks, but then looses connection
            // so it would auto lock, but now it would take the cooldown time to unlock again
            lock(true, true); // Ignoring cooldown here to avoid car being unlocked for too long
        }
        autoLocking = false;

        if (onDisconnected)
            onDisconnected();
    }
};

class MyCallbacks : public BLECharacteristicCallbacks
{
    void onWrite(BLECharacteristic *pCharacteristic)
    {
        std::string value = pCharacteristic->getValue();

        if (value.empty())
        {
            if (DEBUG_MODE)
                Serial.println("Received empty value.");
            return;
        }

        // Every check (structure, HMAC + rolling code, feature, data) happens in here,
        // see lib/OckCore and the tests in test/test_native.
        const ock::CommandDecision decision = ock::processClientMessage(
            verifier, SUPPORTED_FEATURES, reinterpret_cast<const uint8_t *>(value.data()), value.length());
        const ClientCommand command = decision.command;

        if (decision.status != ock::CommandStatus::Accepted)
        {
            if (DEBUG_MODE || decision.status == ock::CommandStatus::StorageError)
                Serial.printf("Rejected command %s (0x%02X): %s (counter: %u)\n",
                              toString(command),
                              static_cast<uint8_t>(command),
                              ock::toString(decision.status),
                              verifier.counter());

            if (ock::shouldReplyInvalidHmac(decision.status))
                sendToClient(Esp32Response::INVALID_HMAC);
            return;
        }

        if (DEBUG_MODE)
            Serial.printf("Received command: %s (0x%02X)\n", toString(command), static_cast<uint8_t>(command));

        switch (command)
        {
        case ClientCommand::GET_VERSION:
            sendToClientString(Esp32Response::VERSION, PROTOCOL_VERSION);
            break;
        case ClientCommand::GET_DATA:
            // One notification per state the vehicle actually supports, with a
            // small gap so they don't get sent faster than the client can be
            // notified. States for unsupported features are not reported at all,
            // so the app doesn't show a state for a button it never renders.
            sendToClient(isLocked ? Esp32Response::LOCKED : Esp32Response::UNLOCKED);
            if (hasFeature(SUPPORTED_FEATURES, Feature::Engine))
            {
                delay(20);
                sendToClient(engineOn ? Esp32Response::ENGINE_STARTED : Esp32Response::ENGINE_STOPPED);
            }
            if (hasFeature(SUPPORTED_FEATURES, Feature::Windows))
            {
                delay(20);
                sendToClient(windowsOpen ? Esp32Response::WINDOWS_OPENED : Esp32Response::WINDOWS_CLOSED);
            }
            break;
        case ClientCommand::LOCK_DOORS:
            lock();
            break;
        case ClientCommand::UNLOCK_DOORS:
            unlock();
            break;
        case ClientCommand::OPEN_TRUNK:
            openTrunk();
            break;
        case ClientCommand::START_ENGINE:
            startEngine();
            break;
        case ClientCommand::STOP_ENGINE:
            stopEngine();
            break;
        case ClientCommand::OPEN_WINDOWS:
            openWindows();
            break;
        case ClientCommand::CLOSE_WINDOWS:
            closeWindows();
            break;
        case ClientCommand::PROXIMITY_KEY_ON:
            enableProxKey();
            break;
        case ClientCommand::PROXIMITY_KEY_OFF:
            disableProxKey();
            break;
        case ClientCommand::RSSI_TRIGGER:
            // Already validated by processClientMessage
            triggerRssiStrength = decision.values[0];
            rssiDeadZone = static_cast<int>(decision.values[1]);
            releaseRssiStrength = ock::calculateReleaseRssi(triggerRssiStrength);

            if (DEBUG_MODE)
            {
                Serial.println("Trigger RSSI set: " + String(triggerRssiStrength));
                Serial.println("Release RSSI set: " + String(releaseRssiStrength));
            }
            break;
        case ClientCommand::GET_RSSI:
            sendRssi = true;
            break;
        case ClientCommand::PROXIMITY_COOLDOWN:
            proximityCooldown = decision.values[0];
            if (DEBUG_MODE)
                Serial.println("Proximity cooldown set: " + String(proximityCooldown));
            break;
        case ClientCommand::GET_FEATURES:
        {
            uint32_t featuresValue = static_cast<uint32_t>(SUPPORTED_FEATURES);
            sendToClient(Esp32Response::FEATURES, reinterpret_cast<const uint8_t *>(&featuresValue), sizeof(featuresValue));
        }
        break;

        default:
            break;
        }
    }
};

// Callback function to handle RSSI readings
void gapCallback(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param)
{
    if (event == ESP_GAP_BLE_READ_RSSI_COMPLETE_EVT)
    {
        // A reading that arrives after a disconnect belongs to the old connection
        if (!deviceConnected)
            return;

        rssiFilter.add(param->read_rssi_cmpl.rssi);
        float avgRSSI = rssiFilter.average();

        if (sendRssi)
        {
            sendToClientFloat(Esp32Response::RSSI, avgRSSI);
            sendRssi = false;
        }

        switch (ock::evaluateProximity(autoLocking, triggerRssiStrength, releaseRssiStrength, rssiFilter, isLocked))
        {
        case ock::ProximityAction::Lock:
            lock(true);
            break;
        case ock::ProximityAction::Unlock:
            unlock(true);
            break;
        default:
            break;
        }
    }
}

std::string scrambleName(const std::string &name)
{
    const char *prefix = "OCK_";
    const uint8_t key = 0x5A;
    std::string input = std::string(prefix) + name;
    std::string output = "";

    for (size_t i = 0; i < input.length(); i++)
    {
        uint8_t x = (uint8_t)input[i] ^ key;
        char buf[3];
        snprintf(buf, sizeof(buf), "%02X", x);
        output += buf;
    }

    return output;
}

void setupBluetooth()
{
    pinMode(bootButtonPin, INPUT_PULLUP);

    // Generate 32-byte HMAC key
    uint8_t sharedSecret[ock::HMAC_SIZE];
    mbedtls_sha256((const unsigned char *)PASSWORD, strlen(PASSWORD), sharedSecret, 0);
    verifier.setKey(sharedSecret);
    memset(sharedSecret, 0, sizeof(sharedSecret));

    // Without a loaded counter every command is refused, a fresh one could accept recorded commands
    if (!verifier.begin())
        Serial.println("ERROR: Could not load the rolling code counter, all commands will be refused. Hold BOOT for 3 seconds to reset it.");
    else if (DEBUG_MODE)
        Serial.printf("Rolling code counter: %u\n", verifier.counter());

    // Create the BLE Device
    BLEDevice::init(scrambleName(DEVICE_NAME));

    // Create the BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create the BLE Service
    BLEService *pService = pServer->createService(SERVICE_UUID);

    BLEDevice::setMTU(BLE_MTU_SIZE);

    // Create the BLE Characteristic
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
            BLECharacteristic::PROPERTY_WRITE |
            BLECharacteristic::PROPERTY_NOTIFY);

    pCharacteristic->setCallbacks(new MyCallbacks());
    pCharacteristic->addDescriptor(new BLE2902());

    // Start the service
    pService->start();

    // Start advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0xA0); // Set minimum connection interval to 200ms
    pAdvertising->setMaxPreferred(0xC8); // Set maximum connection interval to 250ms
    BLEDevice::startAdvertising();

    // Register the GAP callback to receive RSSI results
    esp_ble_gap_register_callback(gapCallback);
}

void readRssi()
{
    if (deviceConnected && (autoLocking || sendRssi))
    {
        unsigned long currentMillis = millis();

        if (currentMillis - previousRssiMillis >= rssiInterval)
        {
            previousRssiMillis = currentMillis;

            esp_ble_gap_read_rssi(peerAddress);
        }
    }
}

void readBootButton()
{
    if (digitalRead(bootButtonPin) == LOW)
    {
        if (!isBootButtonPressed)
        {
            if (DEBUG_MODE)
                Serial.println("BOOT Pressed. hold for 3 seconds to reset rolling code counter");
            bootButtonPressStart = millis();
            isBootButtonPressed = true;
        }
        else if (!counterResetDone && millis() - bootButtonPressStart >= 3000)
        {
            // Only once per press, holding it longer doesn't keep writing to flash
            counterResetDone = true;

            if (verifier.resetCounter())
                Serial.println("Rolling code counter reset");
            else
                Serial.println("ERROR: Could not save the reset rolling code counter");
        }
    }
    else
    {
        isBootButtonPressed = false;
        counterResetDone = false;
    }
}

void bluetoothLoop()
{
    readRssi();
    readBootButton();

    if (deviceConnected && connParamsPending && millis() >= connParamUpdateAt)
    {
        connParamsPending = false;
        // 0xA0*1.25ms=200ms .. 0xC8*1.25ms=250ms, latency 1, timeout 600*10ms=6s
        pServer->updateConnParams(peerAddress, 0xA0, 0xC8, 1, 600);
        if (DEBUG_MODE)
            Serial.println("Requested low-power connection parameters");
    }

    if (!deviceConnected && oldDeviceConnected)
    {
        delay(500);                  // Give the bluetooth stack the chance to get things ready
        pServer->startAdvertising(); // Restart advertising
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected && !oldDeviceConnected)
    {
        oldDeviceConnected = deviceConnected;
    }
}
