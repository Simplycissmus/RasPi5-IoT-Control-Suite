#!/bin/bash
# Version: 1.2.2

# ============================================================================
# Script Name: monitoring_setup.sh
# Description: Module for Monitoring setup (Prometheus & Grafana)
# Author: Patric Aeberhard
# Version: 1.2.2
# Date: 2024-07-15
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

monitoring_setup() {
    log_info "Starting Monitoring setup..."

    # Monitoring setup main function
    setup_monitoring() {
        log_info "Starting Monitoring setup..."

        install_prometheus
        configure_prometheus
        install_grafana
        configure_grafana
        setup_node_exporter
        create_basic_dashboard

        log_info "Monitoring setup completed."
        STATUS["Monitoring Setup"]="Successful"
    }

    # Install Prometheus
    install_prometheus() {
        log_info "Installing Prometheus..."

        local PROMETHEUS_VERSION="2.30.3"
        local PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-arm64.tar.gz"

        run_safely wget ${PROMETHEUS_URL}
        run_safely tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-arm64.tar.gz
        run_safely sudo mv prometheus-${PROMETHEUS_VERSION}.linux-arm64 /opt/prometheus
        run_safely rm prometheus-${PROMETHEUS_VERSION}.linux-arm64.tar.gz

        # Create Prometheus user
        run_safely sudo useradd --no-create-home --shell /bin/false prometheus
        run_safely sudo chown -R prometheus:prometheus /opt/prometheus

        log_info "Prometheus installed."
    }

    # Configure Prometheus
    configure_prometheus() {
        log_info "Configuring Prometheus..."

        # Create Prometheus configuration file
        cat > /opt/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

        # Create systemd service for Prometheus
        cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
    --config.file /opt/prometheus/prometheus.yml \
    --storage.tsdb.path /opt/prometheus/data \
    --web.console.templates=/opt/prometheus/consoles \
    --web.console.libraries=/opt/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

        run_safely sudo systemctl daemon-reload
        run_safely sudo systemctl enable prometheus
        run_safely sudo systemctl start prometheus

        log_info "Prometheus configured and started."
    }

    # Install Grafana
    install_grafana() {
        log_info "Installing Grafana..."

        run_safely sudo apt-get install -y apt-transport-https software-properties-common
        run_safely wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
        run_safely echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
        run_safely sudo apt-get update
        run_safely sudo apt-get install -y grafana

        log_info "Grafana installed."
    }

    # Configure Grafana
    configure_grafana() {
        log_info "Configuring Grafana..."

        # Enable and start Grafana service
        run_safely sudo systemctl daemon-reload
        run_safely sudo systemctl enable grafana-server
        run_safely sudo systemctl start grafana-server

        log_info "Grafana configured and started."
    }

    # Setup Node Exporter
    setup_node_exporter() {
        log_info "Setting up Node Exporter..."

        local NODE_EXPORTER_VERSION="1.2.2"
        local NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64.tar.gz"

        run_safely wget ${NODE_EXPORTER_URL}
        run_safely tar xvfz node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64.tar.gz
        run_safely sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64/node_exporter /usr/local/bin/
        run_safely rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64*

        # Create systemd service for Node Exporter
        cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

        run_safely sudo useradd --no-create-home --shell /bin/false node_exporter
        run_safely sudo systemctl daemon-reload
        run_safely sudo systemctl enable node_exporter
        run_safely sudo systemctl start node_exporter

        log_info "Node Exporter set up and started."
    }

    # Create basic Grafana dashboard
    create_basic_dashboard() {
        log_info "Creating basic Grafana dashboard..."

        # Wait for Grafana to fully start
        sleep 30

        # Add Prometheus as data source
        curl -X POST -H "Content-Type: application/json" -d '{
            "name":"Prometheus",
            "type":"prometheus",
            "url":"http://localhost:9090",
            "access":"proxy",
            "isDefault":true
        }' http://admin:admin@localhost:3000/api/datasources

        # Create a basic dashboard
        curl -X POST -H "Content-Type: application/json" -d '{
            "dashboard": {
                "id": null,
                "title": "System Overview",
                "tags": [ "templated" ],
                "timezone": "browser",
                "rows": [
                    {
                        "title": "CPU Usage",
                        "panels": [
                            {
                                "title": "CPU Usage",
                                "type": "graph",
                                "datasource": "Prometheus",
                                "targets": [
                                    {
                                        "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                                        "legendFormat": "CPU Usage"
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            "overwrite": false
        }' http://admin:admin@localhost:3000/api/dashboards/db

        log_info "Grafana dashboard created."
    }

    setup_monitoring
}

# Execute the monitoring_setup function
monitoring_setup
