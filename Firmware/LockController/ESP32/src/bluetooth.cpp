#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "bluetooth.h"

// BLE service and characteristic UUIDs
#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;

void (*onConnected)() = nullptr;
void (*onDisconnected)() = nullptr;
void (*onLocked)() = nullptr;
void (*onUnlocked)() = nullptr;
void (*onTrunkOpend)() = nullptr;
void (*onEngineStarted)() = nullptr;

bool isLocked = true;
bool deviceConnected = false;
bool isAuthenticated = false;
bool autoLocking = false;

bool oldDeviceConnected = false;

class MyServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer)
    {
        Serial.println("Connected");
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
        if (autoLocking)
        {
            if (onLocked)
                onLocked();
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
            if (command == "ds")
            {
                pCharacteristic->setValue(isLocked ? "ld" : "ud");
                pCharacteristic->notify();
            }
            else if (command == "ld")
            {
                pCharacteristic->setValue("ld");
                pCharacteristic->notify();

                isLocked = true;

                if (onLocked)
                    onLocked();
            }
            else if (command == "ud")
            {
                pCharacteristic->setValue("ud");
                pCharacteristic->notify();

                isLocked = false;

                if (onUnlocked)
                    onUnlocked();
            }
            else if (command == "ut")
            {
                if (onTrunkOpend)
                    onTrunkOpend();
            }
            else if (command == "st")
            {
                if (onEngineStarted)
                    onEngineStarted();
            }
            else if (command == "al")
            {
                autoLocking = true;

                pCharacteristic->setValue("ud");
                pCharacteristic->notify();

                if (isLocked)
                {
                    if (onUnlocked)
                        onUnlocked();
                }
            }
            else if (command == "ald")
            {
                autoLocking = false;
            }
        }
    }
};

void setupBluetooth()
{
    // Create the BLE Device
    BLEDevice::init("ESP32_Lock");

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
}

void bluetoothLoop()
{
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