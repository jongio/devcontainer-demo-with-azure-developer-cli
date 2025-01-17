#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SRC_PATH=$(realpath "${SCRIPT_DIR}/../src/ui/wwwroot")
APP_SETTINGS_FILE="${SRC_PATH}/appsettings.json"

cat << EOF > $APP_SETTINGS_FILE
{
    "API_URI": "${APP_API_BASE_URL}"
}
EOF

echo "Updated ${APP_SETTINGS_FILE}"