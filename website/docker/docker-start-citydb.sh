#!/bin/bash
source /etc/profile.d/citydb.sh
echo "Rebuilding Docker Container"
/usr/local/bin/docker-compose build
echo "Starting Docker Container"
/usr/local/bin/docker-compose up
