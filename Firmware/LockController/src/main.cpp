// Lock Controller code for ESP32 (Not tested yet!)
#include <Arduino.h>
#include "bluetooth.h"

// Pin definitions
const int doorsRelayPin1 = 25;
const int doorsRelayPin2 = 26;
const int trunkRelayPin1 = 27;

void openTrunk()
{
  digitalWrite(trunkRelayPin1, LOW);
  delay(50);
  digitalWrite(trunkRelayPin1, HIGH);
  Serial.println("ut");
}

void unlock()
{
  digitalWrite(doorsRelayPin1, LOW);
  digitalWrite(doorsRelayPin2, HIGH);
  delay(50);
  digitalWrite(doorsRelayPin1, HIGH);
  digitalWrite(doorsRelayPin2, HIGH);
  Serial.println("ud");
}

void lock()
{
  digitalWrite(doorsRelayPin1, HIGH);
  digitalWrite(doorsRelayPin2, LOW);
  delay(50);
  digitalWrite(doorsRelayPin1, HIGH);
  digitalWrite(doorsRelayPin2, HIGH);
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

  digitalWrite(doorsRelayPin1, HIGH); // You might need to swap high and low depending on if your relays are active low
  digitalWrite(doorsRelayPin2, HIGH);
  digitalWrite(trunkRelayPin1, HIGH);

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