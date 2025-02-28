# Container-Metrics
Simple Python app/tool that collects metrics and logs from Docker Containers.

It then exposes those metrics to Prometheus (which just means having an http endpoint) and saves logs in the local file system, limiting their size and rotating files, if necessary (it's also pretty straightforward to save logs somewhere else, in a database for example).

Basic requirements:

•	Python 3.10, compatible pip & deps specified in src/requirements.txt
•	Alternatively just Docker and running it as a container - see _build.sh_
•	Prometheus, if you want to make practical use of the exposed metrics

## How it Works?

_**collector.py**_ is an entry point of the _**metrics-and-logs-collector**_ tool. When started, it reads config from env variables and prints it to the console like this:

`2024-02-11 19:15:47.998 [INFO] collector: Starting collector for local-machine machine!
2024-02-11 19:15:47.998 [INFO] collector: METRICS_COLLECTION_INTERVAL: 20
2024-02-11 19:15:47.998 [INFO] collector: LOGS_COLLECTION_INTERVAL: 5
2024-02-11 19:15:47.998 [INFO] collector: MAX_COLLECTOR_THREADS: 5
2024-02-11 19:15:47.998 [INFO] collector: LAST_METRICS_COLLECTED_AT_FILE: /tmp/last-metrics-collected-at.txt
2024-02-11 19:15:47.998 [INFO] collector: LAST_LOGS_COLLECTED_AT_FILE: /tmp/last-logs-collected-at.txt
2024-02-11 19:15:47.998 [INFO] logs_exporter: LOGS_DIR: /tmp/logs
2024-02-11 19:15:47.998 [INFO] logs_exporter: LOGS_CONTAINER_MAX_FILES: 10
2024-02-11 19:15:47.998 [INFO] logs_exporter: LOGS_CONTAINER_MAX_FILE_SIZE: 10485760
2024-02-11 19:15:47.998 [INFO] logs_exporter: LOG_LEVELS_MAPPING_PATH: /config/log_levels_mapping.json

2024-02-11 19:15:47.998 [INFO] collector: Trying to get client...
2024-02-11 19:15:48.011 [INFO] collector: Client connected, docker version: {
  "Platform": {
    "Name": "Docker Engine - Community"
  },
  "Components": [
    {
      "Name": "Engine",
      "Version": "25.0.3",
      "Details": {
        "ApiVersion": "1.44",
        "Arch": "amd64",
        "BuildTime": "2024-02-06T21:14:17.000000000+00:00",
        "Experimental": "false",
        "GitCommit": "f417435",
        "GoVersion": "go1.21.6",
        "KernelVersion": "6.5.0-17-generic",
        "MinAPIVersion": "1.24",
        "Os": "linux"
      }
    },
    {
      "Name": "containerd",
      "Version": "1.6.28",
      "Details": {
        "GitCommit": "ae07eda36dd25f8a1b98dfbf587313b99c0190bb"
      }
    },
    {
      "Name": "runc",
      "Version": "1.1.12",
      "Details": {
        "GitCommit": "v1.1.12-0-g51d5e94"
      }
    },
    {
      "Name": "docker-init",
      "Version": "0.19.0",
      "Details": {
        "GitCommit": "de40ad0"
      }
    }
  ],
  "Version": "25.0.3",
  "ApiVersion": "1.44",
  "MinAPIVersion": "1.24",
  "GitCommit": "f417435",
  "GoVersion": "go1.21.6",
  "Os": "linux",
  "Arch": "amd64",
  "KernelVersion": "6.5.0-17-generic",
  "BuildTime": "2024-02-06T21:14:17.000000000+00:00"
}

2024-02-11 19:15:48.012 [INFO] collector: Metrics are exported on port 10101`

After this warm welcome, it tries to connect to the **_Docker Engine_**, retrying as many times as needed.

Then, the flow continues in the following, infinite loop:

* get running containers from Containers class
* if needed, collect metrics according to METRICS_COLLECTION_INTERVAL, using MAX_COLLECTOR_THREADS to make it faster
* if new metrics were collected:
    - update metrics in metrics_exporter.py so that Prometheus can scrape up-to-date values
    - update LAST_METRICS_COLLECTED_AT_FILE with new timestamp value
* sleep for LOGS_COLLECTION_INTERVAL (it is always <= METRICS_COLLECTION_INTERVAL) and then repeat the whole process again, as long as the program is alive
## How you can make it work?
All you need is an ability to run Docker and most likely Linux-based system (might work on others also, but it is not guaranteed).

From containers directory run:
`./build.sh`
After a while, which can take some time - Docker might need to pull multiple base images from the net, you should run:
`docker ps`
and see:
`CONTAINER ID   IMAGE             COMMAND                  CREATED              STATUS              PORTS 
e8776b8fed48   metrics-and-logs-collector                 "python3 -u collecto…"   52 minutes ago      Up 52 minutes             0.0.0.0:9093->9093/tcp, :::9093->9093/tcp`
## Prometheus
