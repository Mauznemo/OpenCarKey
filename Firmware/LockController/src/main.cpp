// Lock Controller code for ESP32 (Not tested yet!)
#include <Arduino.h>
#include "bluetooth.h"

// Pin definitions
const int doorsRelayPin1 = 15;
const int doorsRelayPin2 = 16;
const int trunkRelayPin1 = 17;

void openTrunk()
{
  digitalWrite(trunkRelayPin1, HIGH);
  delay(50);
  digitalWrite(trunkRelayPin1, LOW);
  Serial.println("ut");
}

void unlock()
{
  digitalWrite(doorsRelayPin1, HIGH);
  digitalWrite(doorsRelayPin2, LOW);
  delay(50);
  digitalWrite(doorsRelayPin1, LOW);
  digitalWrite(doorsRelayPin2, LOW);
  Serial.println("ud");
}

void lock()
{
  digitalWrite(doorsRelayPin1, LOW);
  digitalWrite(doorsRelayPin2, HIGH);
  delay(50);
  digitalWrite(doorsRelayPin1, LOW);
  digitalWrite(doorsRelayPin2, LOW);
  Serial.println("ld");
}

void checkSerial()
{
  if (Serial.available() > 0)
  {
    String data = Serial.readStringUntil('\n');
    if (data == "ld")
    {
      lock();
    }
    else if (data == "ud")
    {
      unlock();
    }
    else if (data == "ut")
    {
      openTrunk();
    }
  }
}

void setup()
{
  if (DEBUG_MODE)
    Serial.println("Starting BLE Lock Controller (Protocol version: " + PROTOCOL_VERSION + ")");
  // Initialize pins
  pinMode(doorsRelayPin1, OUTPUT);
  pinMode(doorsRelayPin2, OUTPUT);
  pinMode(trunkRelayPin1, OUTPUT);

  digitalWrite(doorsRelayPin1, LOW);
  digitalWrite(doorsRelayPin2, LOW);
  digitalWrite(trunkRelayPin1, LOW);

  Serial.begin(115200);

  setupBluetooth();

  onLocked = lock;
  onUnlocked = unlock;
  onTrunkOpened = openTrunk;

  if (DEBUG_MODE)
    Serial.println("BLE Lock Controller Ready");
}

void loop()
{
  checkSerial();
  bluetoothLoop();
}