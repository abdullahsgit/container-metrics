#!/bin/bash

container="metrics-collector"

docker stop $container

docker rm $container

docker build . -t $container

export LOG_LEVELS_MAPPING_PATH="/config/log_levels_mapping.json"

# /var/run/docker.sock is needed to access containers of the host machine.
# It works on Linux-based systems, might be something different on Mac/Linux.
# In the /tmp/metrics-and-logs-collector we store logs and files with last metrics/logs collection timestamps.
docker run -d --memory "250M" --cpus "1" -p "9103:9103" \
  --env LOG_LEVELS_MAPPING_PATH \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /tmp/metrics-collector:/tmp \
  --name $container $container 
