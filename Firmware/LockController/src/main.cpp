// Lock Controller code for ESP32 (Not tested yet!)
#include <Arduino.h>
#include "bluetooth/bluetooth.h"
#include "config.h"
#include <ESP32Servo.h>

// Pin definitions
const int lockServoPin = 13;

Servo lockServo;

void unlock(bool proximity)
{
  lockServo.attach(lockServoPin);
  lockServo.write(120);
  delay(1000);
  lockServo.detach();
  Serial.println("ud");
}

void lock(bool proximity)
{
  lockServo.attach(lockServoPin);
  lockServo.write(80);
  delay(1000);
  lockServo.detach();
  Serial.println("ld");
}

void checkSerial()
{
  if (Serial.available() > 0)
  {
    String data = Serial.readStringUntil('\n');
    if (data == "ld")
    {
      lock(false);
    }
    else if (data == "ud")
    {
      unlock(false);
    }
  }
}

void setup()
{
  Serial.println("Starting BLE Lock Controller");
  // Initialize pins

  Serial.begin(115200);
  lock(false);

  setupBluetooth();

  onLocked = lock;
  onUnlocked = unlock;

  if (DEBUG_MODE)
    Serial.println("BLE Lock Controller Ready");
}

void loop()
{
  checkSerial();
  bluetoothLoop();
}