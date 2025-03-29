// Keyfob code for ESP32 (Hardware alternative to mobile app)
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128    // OLED display width, in pixels
#define SCREEN_HEIGHT 64    // OLED display height, in pixels (might be 32 for some displays)
#define OLED_RESET -1       // Reset pin (-1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3C // Typical I2C address (might be 0x3D for some displays)

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup()
{
  Serial.begin(115200);

  // Initialize I2C
  Wire.begin(21, 22); // SDA=21, SCL=22

  // Initialize display
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS))
  {
    Serial.println(F("SSD1306 allocation failed"));
    for (;;)
      ; // Don't proceed, loop forever
  }

  // Show initial display
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(2, 10);
  display.println(F("Hello, ESP32!"));
  display.setCursor(2, 25);
  display.fillRect(0, 24, SCREEN_WIDTH, 10, SSD1306_WHITE); // Adjust height as needed
  // Now place text on top with offset
  display.setTextColor(SSD1306_BLACK);
  display.println(F("OLED Test"));
  display.display();
}

void loop()
{
  // Your code here
}