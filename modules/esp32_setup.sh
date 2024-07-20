#!/bin/bash
# Version: 1.2.2

# ============================================================================
# Script Name: esp32_setup.sh
# Description: Module for ESP32 communication setup
# Author: Patric Aeberhard (with updates by AI Assistant)
# Version: 1.2.2
# Date: 2024-07-16
# ============================================================================

# Set up script directory and log directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../log"
UTILS_DIR="${SCRIPT_DIR}/../utils"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log file setup
export LOG_FILE="${LOG_DIR}/iot_setup.log"

# Error handling and logging functions
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

esp32_setup() {
    log_info "Starting ESP32 setup..."

    create_mqtt_bridge
    update_backend_for_esp32
    create_esp32_example_code

    if [ $? -eq 0 ]; then
        log_info "ESP32 communication setup completed successfully."
        return 0
    else
        log_error "ESP32 communication setup failed."
        return 1
    fi
}

create_mqtt_bridge() {
    log_info "Creating MQTT bridge..."

    cat > "${PROJECT_DIR}/mqtt_bridge.py" <<EOF
import paho.mqtt.client as mqtt
from flask_socketio import emit
import json

class MQTTBridge:
    def __init__(self, socketio, broker_address="${MQTT_BROKER}", broker_port=1883):
        self.client = mqtt.Client()
        self.client.username_pw_set("${MQTT_USER}", "${MQTT_PASSWORD}")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.socketio = socketio
        self.broker_address = broker_address
        self.broker_port = broker_port

    def connect(self):
        self.client.connect(self.broker_address, self.broker_port, 60)
        self.client.loop_start()

    def on_connect(self, client, userdata, flags, rc):
        print(f"Connected with result code {rc}")
        self.client.subscribe("esp32/#")

    def on_message(self, client, userdata, msg):
        print(f"Received message on topic {msg.topic}: {msg.payload.decode()}")
        try:
            data = json.loads(msg.payload.decode())
            self.socketio.emit('esp32_data', {'topic': msg.topic, 'data': data})
        except json.JSONDecodeError:
            print(f"Failed to decode JSON: {msg.payload.decode()}")

    def publish(self, topic, message):
        self.client.publish(topic, message)

mqtt_bridge = None

def init_mqtt_bridge(socketio):
    global mqtt_bridge
    mqtt_bridge = MQTTBridge(socketio)
    mqtt_bridge.connect()

def get_mqtt_bridge():
    return mqtt_bridge
EOF

    log_info "MQTT bridge created."
}

update_backend_for_esp32() {
    log_info "Updating backend for ESP32 communication..."

    # Add MQTT bridge to backend
    sed -i '/import paho.mqtt.client as mqtt/d' "${PROJECT_DIR}/app.py"
    sed -i '1ifrom mqtt_bridge import init_mqtt_bridge, get_mqtt_bridge' "${PROJECT_DIR}/app.py"

    # Initialize MQTT bridge
    sed -i '/socketio = SocketIO(app)/a\init_mqtt_bridge(socketio)' "${PROJECT_DIR}/app.py"

    # Add route for ESP32 control
    cat >> "${PROJECT_DIR}/app.py" <<EOF

@app.route('/api/control_esp32', methods=['POST'])
def control_esp32():
    data = request.json
    mqtt_bridge = get_mqtt_bridge()
    mqtt_bridge.publish(f"esp32/{data['device_id']}/control", json.dumps(data['command']))
    return jsonify({"status": "success", "message": "Command sent to ESP32"})
EOF

    log_info "Backend updated for ESP32 communication."
}

create_esp32_example_code() {
    log_info "Creating ESP32 example code..."

    mkdir -p "${PROJECT_DIR}/esp32_examples"
    cat > "${PROJECT_DIR}/esp32_examples/esp32_mqtt_example.ino" <<EOF
#include <WiFi.h>
#include <PubSubClient.h>

const char* ssid = "${WIFI_SSID}";
const char* password = "${WIFI_PASSPHRASE}";
const char* mqtt_server = "${MQTT_BROKER}";
const int mqtt_port = 1883;
const char* mqtt_user = "${MQTT_USER}";
const char* mqtt_password = "${MQTT_PASSWORD}";

WiFiClient espClient;
PubSubClient client(espClient);

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  // Add your control logic here
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_password)) {
      Serial.println("connected");
      client.subscribe("esp32/+/control");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Add your sensor reading and publishing logic here
}
EOF

    log_info "ESP32 example code created."
}

# Execute the esp32_setup function
esp32_setup
