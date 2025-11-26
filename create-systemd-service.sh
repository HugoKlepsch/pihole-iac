#!/bin/bash -e
# Create a systemd service that autostarts & manages a docker-compose instance in the current directory
# by Uli Köhler - https://techoverflow.net
# Licensed as CC0 1.0 Universal
# Modified by Hugo Klepsch

set -euo pipefail

SERVICENAME=$(basename $(pwd))

# Load variables
ENV_FILE=".env.bash"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE file not found." >&2
  exit 1
fi

# Use 'set -a' to export all sourced variables to the environment
set -a
if ! source "$ENV_FILE"; then
  echo "Error: Failed to source $ENV_FILE." >&2
  exit 1
fi
set +a
echo "$ENV_FILE loaded successfully."

# Create generated_config directory, where the generated unit files go before they are installed
GEN_DIR="$(pwd)/generated_config"
mkdir -p "${GEN_DIR}"
echo "Generated units are written to ${GEN_DIR}/ before installation"

pihole_unit_name="${SERVICENAME}.service"
echo "Creating pihole systemd service... ${pihole_unit_name}"
# Create systemd service file
cat >"${GEN_DIR}/${pihole_unit_name}" <<EOF
[Unit]
Description=Run pihole in docker compose
After=docker.service
Requires=docker.service

[Service]
RestartSec=10
Restart=always
User=root
Group=docker
WorkingDirectory=$(pwd)
# Shutdown container (if running) when unit is started
ExecStartPre=/bin/bash -c ". ${ENV_FILE}; $(which docker) compose -f docker-compose.yml down"
# Start container when unit is started
ExecStart=/bin/bash -c ". ${ENV_FILE}; $(which docker) compose -f docker-compose.yml up"
# Stop container when unit is stopped
ExecStop=/bin/bash -c ". ${ENV_FILE}; $(which docker) compose -f docker-compose.yml down"

[Install]
WantedBy=multi-user.target
EOF

if [[ "${INSTALL:-false}" == "true" ]]; then
	echo "Installing pihole systemd service... /etc/systemd/system/${pihole_unit_name}"
	sudo cp "${GEN_DIR}/${pihole_unit_name}" "/etc/systemd/system/${pihole_unit_name}"

	sudo systemctl daemon-reload

	if [[ "${ENABLE_NOW:-false}" == "true" ]]; then
		echo "Enabling & starting ${pihole_unit_name}"
		# Start systemd units on startup (and right now)
		sudo systemctl enable --now "${pihole_unit_name}"
		exit 0
	else
		echo "Run with INSTALL=true ENABLE_NOW=true ./create... to install and start and enable"
		exit 0
	fi
else
	echo "Run with INSTALL=true ./create... to install"
	exit 0
fi

exit 0
