#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "bluetooth.h"
#include "esp_gap_ble_api.h"
#include "commands.h"

#define BLE_MTU_SIZE 64
// BLE service and characteristic UUIDs
#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

#define RSSI_SAMPLES 5 // Number of samples for smoothing

const std::string PROTOCOL_VERSION = "V2";

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
esp_bd_addr_t peerAddress;

void (*onConnected)() = nullptr;
void (*onDisconnected)() = nullptr;
void (*onLocked)() = nullptr;
void (*onUnlocked)() = nullptr;
void (*onTrunkOpened)() = nullptr;
void (*onEngineStarted)() = nullptr;

bool isLocked = true;
bool deviceConnected = false;
bool isAuthenticated = false;
bool autoLocking = false;

bool oldDeviceConnected = false;

float triggerRssiStrength = 0;
float releaseRssiStrength = 0;
float lastRssiStrength = 0;
int rssiDeadZone = 4;
int rssiBuffer[RSSI_SAMPLES] = {0};
int rssiIndex = 0;
bool bufferFilled = false;
unsigned long previousRssiMillis = 0;
const long rssiInterval = 500;
bool sendRssi = false;
float proximityCooldown = 1; // in min
unsigned long previousProximityMillis = 0;
static int authAttempts = 0;
static unsigned long lastAuthAttemptMillis = 0;
const unsigned long authCooldownMillis = 10000;

void sendToClinet(Esp32Response responseCode, const std::string &additionalDataString = "")
{

    size_t stringLen = additionalDataString.length();

    if (stringLen > 12)
    {
        Serial.println("Warning: additionalDataString truncated to 12 bytes.");
        stringLen = 12;
    }

    // Calculate total buffer size: 1 byte for command + 1 byte for string length + string data
    size_t totalBufferSize = 1;

    if (stringLen > 0)
    {
        totalBufferSize += 1;         // Add 1 byte for string length
        totalBufferSize += stringLen; // Add bytes for the string data
    }

    std::vector<uint8_t> responseBuffer(totalBufferSize);

    responseBuffer[0] = static_cast<uint8_t>(responseCode);

    if (DEBUG_MODE)
        Serial.printf("Sent ESP32 Response: 0x%02X\n", static_cast<uint8_t>(responseCode));

    if (stringLen > 0)
    {
        responseBuffer[1] = static_cast<uint8_t>(stringLen);                        // String length byte
        memcpy(responseBuffer.data() + 2, additionalDataString.c_str(), stringLen); // Copy string data

        if (DEBUG_MODE)
            Serial.printf(", String Length: %zu, Data: \"%s\"\n", stringLen, additionalDataString.substr(0, stringLen).c_str());
    }

    pCharacteristic->setValue(responseBuffer.data(), totalBufferSize);
    pCharacteristic->notify();
}

namespace
{
    void lock(bool proximity = false, bool ignoreCooldown = false)
    {
        if (proximity &&
            proximityCooldown != 0 &&
            !ignoreCooldown &&
            ((millis() - previousProximityMillis) < (proximityCooldown * 60000)))
        {
            return;
        }

        if (proximity)
            previousProximityMillis = millis();

        if (deviceConnected)
        {
            sendToClinet(proximity ? Esp32Response::PROXIMITY_LOCKED : Esp32Response::LOCKED);
        }

        isLocked = true;

        if (onLocked)
            onLocked();

        if (DEBUG_MODE)
            Serial.println("Locked (proximity:" + String(proximity) + ")");
    }

    void unlock(bool proximity = false, bool ignoreCooldown = false)
    {

        if (proximity &&
            proximityCooldown != 0 &&
            !ignoreCooldown &&
            ((millis() - previousProximityMillis) < (proximityCooldown * 60000)))
        {
            return;
        }

        if (proximity)
            previousProximityMillis = millis();

        if (deviceConnected)
        {
            sendToClinet(proximity ? Esp32Response::PROXIMITY_UNLOCKED : Esp32Response::UNLOCKED);
        }

        isLocked = false;

        if (onUnlocked)
            onUnlocked();

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
        if (onEngineStarted)
            onEngineStarted();
    }

    void enableProxKey()
    {
        autoLocking = true;
    }

    void disableProxKey()
    {
        autoLocking = false;
    }

    float calculateReleaseRssi(int triggerRssiStrength, float pathLossExponent = 3.0, float reduction = 5.0)
    {
        float deltaRssi = -10 * pathLossExponent * log10((reduction + 1) / 1);
        return triggerRssiStrength + deltaRssi;
    }
}

class MyServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer, esp_ble_gatts_cb_param_t *param)
    {
        if (DEBUG_MODE)
            Serial.println("Connected");
        memcpy(peerAddress, param->connect.remote_bda, sizeof(esp_bd_addr_t));
        deviceConnected = true;
        isAuthenticated = false; // Reset authentication on new connection

        if (onConnected)
            onConnected();
    };

    void onDisconnect(BLEServer *pServer)
    {
        if (DEBUG_MODE)
            Serial.println("Disconnected");
        deviceConnected = false;
        isAuthenticated = false;      // Reset authentication on disconnect
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
        size_t length = value.length();

        if (length == 0)
        {
            if (DEBUG_MODE)
                Serial.println("Received empty value.");
            return;
        }

        if (length < 33)
        { // Minimum for HMAC + Command
            Serial.println("Received malformed client command: too short.");
            // TODO: send error
            return;
        }

        uint8_t receivedHmac[32];
        memcpy(receivedHmac, value.data(), 32);

        // TODO: Check HMAC

        uint8_t commandByte[1];
        memcpy(commandByte, value.data() + 32, 1);
        ClientCommand command = static_cast<ClientCommand>(commandByte[0]);

        uint8_t additionalLength = value.data()[33];

        std::string additionalDataString;

        if (additionalLength > 0)
        {
            std::vector<uint8_t> additionalData(additionalLength);
            memcpy(additionalData.data(), value.data() + 34, additionalLength);
            additionalDataString = std::string(additionalData.begin(), additionalData.end());

            if (DEBUG_MODE)
                Serial.printf("Received additional data: %s\n", additionalDataString.c_str());
        }

        if (DEBUG_MODE)
            Serial.printf("Received command: 0x%02X\n", static_cast<uint8_t>(command));

        switch (command)
        {
        case ClientCommand::GET_VERSION:
            sendToClinet(Esp32Response::VERSION, PROTOCOL_VERSION.c_str());
            break;
        case ClientCommand::GET_DATA:
            sendToClinet(isLocked ? Esp32Response::LOCKED : Esp32Response::UNLOCKED);
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
        case ClientCommand::PROXIMITY_KEY_ON:
            enableProxKey();
            break;
        case ClientCommand::PROXIMITY_KEY_OFF:
            disableProxKey();
            break;
        case ClientCommand::RSSI_TRIGGER:
        {
            if (additionalDataString.length() == 0)
            {
                if (DEBUG_MODE)
                    Serial.println("No RSSI trigger data");
                return;
            }

            String additionalDataStringArd = String(additionalDataString.c_str()); // Use Arduino String to get util functions
            int index = additionalDataStringArd.indexOf(',');
            triggerRssiStrength = additionalDataStringArd.substring(0, index).toFloat();
            rssiDeadZone = additionalDataStringArd.substring(index + 1).toInt();

            triggerRssiStrength = triggerRssiStrength;
            releaseRssiStrength = calculateReleaseRssi(triggerRssiStrength);

            if (DEBUG_MODE)
            {
                Serial.println("Trigger RSSI set: " + String(triggerRssiStrength));
                Serial.println("Release RSSI set: " + String(releaseRssiStrength));
            }
        }
        break;
        case ClientCommand::GET_RSSI:
            sendRssi = true;
            break;
        case ClientCommand::PROXIMITY_COOLDOWN:
        {
            if (additionalDataString.length() == 0)
            {
                if (DEBUG_MODE)
                    Serial.println("No RSSI trigger data");
                return;
            }

            String additionalDataStringArd = String(additionalDataString.c_str()); // Use Arduino String to get util functions
            proximityCooldown = additionalDataStringArd.toFloat();
            if (DEBUG_MODE)
                Serial.println("Proximity cooldown set: " + String(proximityCooldown));
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
        int rawRSSI = param->read_rssi_cmpl.rssi;

        rssiBuffer[rssiIndex] = rawRSSI;
        rssiIndex = (rssiIndex + 1) % RSSI_SAMPLES;

        if (rssiIndex == 0)
            bufferFilled = true;

        int sum = 0;
        int count = bufferFilled ? RSSI_SAMPLES : rssiIndex;
        for (int i = 0; i < count; i++)
        {
            sum += rssiBuffer[i];
        }
        float avgRSSI = (float)sum / count;

        if (sendRssi)
        {
            sendToClinet(Esp32Response::RSSI, String(avgRSSI).c_str());
            sendRssi = false;
        }

        if (!autoLocking || triggerRssiStrength == 0)
        {
            return;
        }

        if (avgRSSI < releaseRssiStrength)
        {
            if (!isLocked)
            {
                lock(true);
            }
        }
        else if (avgRSSI > triggerRssiStrength)
        {
            if (isLocked)
            {
                unlock(true);
            }
        }
    }
}

void setupBluetooth()
{
    // Create the BLE Device
    BLEDevice::init(DEVICE_NAME);

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
    pAdvertising->setMinPreferred(0x06); // Set minimum connection interval to 7.5ms
    pAdvertising->setMaxPreferred(0x10); // Set maximum connection interval to 20ms
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

void bluetoothLoop()
{
    readRssi();

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