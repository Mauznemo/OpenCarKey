#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "bluetooth.h"
#include "esp_gap_ble_api.h"
#include "commands.h"
#include <mbedtls/sha256.h>
#include <mbedtls/md.h>
#include <SPIFFS.h>

#define BLE_MTU_SIZE 64
// BLE service and characteristic UUIDs
#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

#define RSSI_SAMPLES 5 // Number of samples for smoothing

const std::string PROTOCOL_VERSION = "V3";

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
esp_bd_addr_t peerAddress;

uint8_t sharedSecret[32];
uint32_t counter = 0;

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

const int bootButtonPin = 0;
unsigned long bootButtonPressStart = 0;
bool isBootButtonPressed = false;

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
            sendToClient(proximity ? Esp32Response::PROXIMITY_LOCKED : Esp32Response::LOCKED);
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
            sendToClient(proximity ? Esp32Response::PROXIMITY_UNLOCKED : Esp32Response::UNLOCKED);
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

void writeCounter(uint32_t count)
{
    File file = SPIFFS.open("/counter", "w"); // Using SPIFFS to avoid wearing flash sinc it has way more sectores
    file.print(count);
    file.close();
}

uint32_t readCounter()
{
    File file = SPIFFS.open("/counter", "r");
    uint32_t count = file.parseInt();
    file.close();
    return count;
}

// Generate HMAC-SHA256 for a counter and 1-byte command
void generateHMAC(uint32_t counter, uint8_t command, uint8_t *hmac)
{
    mbedtls_md_context_t ctx;
    mbedtls_md_init(&ctx);
    mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 1); // 1 = HMAC
    mbedtls_md_hmac_starts(&ctx, sharedSecret, 32);
    mbedtls_md_hmac_update(&ctx, (const uint8_t *)&counter, sizeof(counter));
    mbedtls_md_hmac_update(&ctx, &command, 1);
    mbedtls_md_hmac_finish(&ctx, hmac);
    mbedtls_md_free(&ctx);
}

// Verify HMAC-SHA256 for a counter and 1-byte command
bool verifyHMAC(uint32_t counter, uint8_t command, const uint8_t *received_hmac)
{
    uint8_t expected_hmac[32];
    generateHMAC(counter, command, expected_hmac);
    return memcmp(received_hmac, expected_hmac, 32) == 0;
}

float parseFloat(const uint8_t *data)
{
    if (data == nullptr)
        return 0.0f;
    float value;
    memcpy(&value, data, sizeof(float));
    return value;
}

int32_t parseInt32(const uint8_t *data)
{
    if (data == nullptr)
        return 0;
    int32_t value;
    memcpy(&value, data, sizeof(int32_t));
    return value;
}

int16_t parseInt16(const uint8_t *data)
{
    if (data == nullptr)
        return 0;
    int16_t value;
    memcpy(&value, data, sizeof(int16_t));
    return value;
}

uint8_t parseUint8(const uint8_t *data)
{
    if (data == nullptr)
        return 0;
    return data[0];
}

std::string parseString(const uint8_t *data, uint8_t length)
{
    if (data == nullptr || length == 0)
        return "";
    return std::string(reinterpret_cast<const char *>(data), length);
}

// Parse multiple floats (e.g., GPS coordinates)
void parseFloats(const uint8_t *data, float *output, size_t count)
{
    if (data == nullptr || output == nullptr)
        return;
    for (size_t i = 0; i < count; i++)
    {
        memcpy(&output[i], data + (i * sizeof(float)), sizeof(float));
    }
}

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
            sendToClient(Esp32Response::INVALID_HMAC);
            return;
        }

        uint8_t receivedHmac[32];
        memcpy(receivedHmac, value.data(), 32);

        uint8_t commandByte[1];
        memcpy(commandByte, value.data() + 32, 1);
        ClientCommand command = static_cast<ClientCommand>(commandByte[0]);

        uint8_t additionalLength = 0;
        const uint8_t *additionalDataPtr = nullptr;

        if (length > 33)
        {
            additionalLength = value.data()[33];

            // Verify we have enough data
            if (length >= 34 + additionalLength)
            {
                additionalDataPtr = reinterpret_cast<const uint8_t *>(value.data() + 34);
            }
            else
            {
                Serial.println("Malformed data: advertised length exceeds actual data.");
                return;
            }
        }

        // Verify HMAC with a window of 10 counters to handle small desyncs
        bool valid = false;
        for (int i = 0; i < 10; i++)
        {
            if (verifyHMAC(counter + i, commandByte[0], receivedHmac))
            {
                valid = true;
                counter = counter + i + 1;
                writeCounter(counter);
                break;
            }
        }

        if (!valid)
        {
            if (DEBUG_MODE)
                Serial.println("Received invalid HMAC. Tested counters: " + String(counter) + "-" + String(counter + 10));
            sendToClient(Esp32Response::INVALID_HMAC);
            return;
        }

        if (DEBUG_MODE)
            Serial.printf("Received command: 0x%02X with %d bytes of data\n",
                          static_cast<uint8_t>(command), additionalLength);

        switch (command)
        {
        case ClientCommand::GET_VERSION:
            sendToClientString(Esp32Response::VERSION, PROTOCOL_VERSION.c_str());
            break;
        case ClientCommand::GET_DATA:
            sendToClient(isLocked ? Esp32Response::LOCKED : Esp32Response::UNLOCKED);
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
            if (additionalLength == 0)
            {
                if (DEBUG_MODE)
                    Serial.println("No RSSI trigger data");
                return;
            }

            float additionalDataFloats[2];
            parseFloats(additionalDataPtr, additionalDataFloats, 2);

            triggerRssiStrength = additionalDataFloats[0];
            rssiDeadZone = additionalDataFloats[1];

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
            if (additionalLength == 0)
            {
                if (DEBUG_MODE)
                    Serial.println("No RSSI trigger data");
                return;
            }

            proximityCooldown = parseFloat(additionalDataPtr);
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
            sendToClientFloat(Esp32Response::RSSI, avgRSSI);
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
    if (SPIFFS.begin(true))
    {
        counter = readCounter();
    }
    else if (DEBUG_MODE)
    {
        Serial.println("SPIFFS Mount Failed");
    }

    pinMode(bootButtonPin, INPUT_PULLUP);

    // Generate 32-byte HMAC key
    mbedtls_sha256((const unsigned char *)PASSWORD, strlen(PASSWORD), sharedSecret, 0);

    if (DEBUG_MODE)
    {
        Serial.print("Generated 32-byte key (from: " + String(PASSWORD) + "): ");
        for (int i = 0; i < 32; i++)
        {
            Serial.printf("%02x", sharedSecret[i]);
        }
        Serial.println();
    }

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

void readBootButton()
{
    if (digitalRead(bootButtonPin) == LOW)
    {
        if (!isBootButtonPressed)
        {
            if (DEBUG_MODE)
                Serial.println("BOOT Pressed. hold for 5 seconds to reset rolling code counter");
            bootButtonPressStart = millis();
            isBootButtonPressed = true;
        }
        else if (millis() - bootButtonPressStart >= 3000)
        {
            if (DEBUG_MODE)
                Serial.println("Resseting rolling code counter");

            counter = 0;
            writeCounter(counter);
            delay(1000);
        }
    }
    else
    {
        isBootButtonPressed = false;
    }
}

void bluetoothLoop()
{
    readRssi();
    readBootButton();

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