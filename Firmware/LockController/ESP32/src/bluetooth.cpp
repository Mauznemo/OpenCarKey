#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "bluetooth.h"
#include "esp_gap_ble_api.h"

// BLE service and characteristic UUIDs
#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

#define RSSI_SAMPLES 5 // Number of samples for smoothing

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

namespace
{
    void lock(bool proximity = false)
    {
        if (deviceConnected)
        {
            pCharacteristic->setValue(proximity ? "LOCKED_PROX" : "LOCKED");
            pCharacteristic->notify();
        }

        isLocked = true;

        if (onLocked)
            onLocked();

        Serial.println("Locked (proximity:" + String(proximity) + ")");
    }

    void unlock(bool proximity = false)
    {
        if (deviceConnected)
        {
            pCharacteristic->setValue(proximity ? "UNLOCKED_PROX" : "UNLOCKED");
            pCharacteristic->notify();
        }

        isLocked = false;

        if (onUnlocked)
            onUnlocked();

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
        Serial.println("Connected");
        memcpy(peerAddress, param->connect.remote_bda, sizeof(esp_bd_addr_t));
        deviceConnected = true;
        isAuthenticated = false; // Reset authentication on new connection

        if (onConnected)
            onConnected();
    };

    void onDisconnect(BLEServer *pServer)
    {
        Serial.println("Disconnected");
        deviceConnected = false;
        isAuthenticated = false; // Reset authentication on disconnect
        if (autoLocking && !isLocked)
        {
            lock(true);
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
        if (value.length() > 0)
        {
            String command = String(value.c_str());
            command.trim();

            Serial.println("Received command: " + command);

            // Handle authentication
            if (command.startsWith("AUTH:"))
            {
                String receivedPin = command.substring(5);
                if (receivedPin == LOCK_PIN)
                {
                    isAuthenticated = true;
                    pCharacteristic->setValue("AUTH_OK");
                    pCharacteristic->notify();
                }
                else
                {
                    pCharacteristic->setValue("AUTH_FAIL");
                    pCharacteristic->notify();
                }
                return;
            }

            // Only process commands if authenticated
            if (!isAuthenticated)
            {
                Serial.println("Not authenticated");
                pCharacteristic->setValue("NOT_AUTH");
                pCharacteristic->notify();
                return;
            }

            // Process authenticated commands
            if (command == "SEND_DATA")
            {
                pCharacteristic->setValue(isLocked ? "LOCKED" : "UNLOCKED");
                pCharacteristic->notify();
            }
            else if (command == "LOCK")
            {
                lock();
            }
            else if (command == "UNLOCK")
            {
                unlock();
            }
            else if (command == "OPEN_TRUNK")
            {
                openTrunk();
            }
            else if (command == "START_ENGINE")
            {
                startEngine();
            }
            else if (command == "PROX_KEY_ON")
            {
                enableProxKey();
            }
            else if (command == "PROX_KEY_OFF")
            {
                disableProxKey();
            }
            else if (command.startsWith("RSSI_TRIG:"))
            {
                String data = command.substring(10);
                int index = data.indexOf(',');
                triggerRssiStrength = data.substring(0, index).toFloat();
                rssiDeadZone = data.substring(index + 1).toInt();
                triggerRssiStrength = command.substring(10).toFloat();
                releaseRssiStrength = calculateReleaseRssi(triggerRssiStrength);
                Serial.println("Trigger RSSI set: " + String(triggerRssiStrength));
                Serial.println("Release RSSI set: " + String(releaseRssiStrength));
            }
            else if (command == "RSSI")
            {
                sendRssi = true;
            }
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
            pCharacteristic->setValue(("RSSI:" + String(avgRSSI)).c_str());
            pCharacteristic->notify();
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