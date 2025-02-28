# Metrics and Logs Collector

Simple Python app/tool that collects metrics and logs from Docker Containers. 

It then exposes those metrics to Prometheus (which just means having an http endpoint) and saves logs in the local file system, limiting their size and rotating files, if necessary (it's also pretty straightforward to save logs somewhere else, in a database for example).

Basic requirements:
* Python 3.10, compatible pip & deps specified in src/requirements.txt
* Alternatively just Docker and running it as a container - see ***build.sh***
* Prometheus, if you want to make practical use of the exposed metrics

## How it works

***collector.py*** is an entry point of the ***metrics-and-logs-collector*** tool.
When started, it reads config from env variables and prints it to the console like this:
```
2024-02-11 19:15:47.998 [INFO] collector: Starting collector for local-machine machine!
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

2024-02-11 19:15:48.012 [INFO] collector: Metrics are exported on port 9103
```

After this warm welcome, it tries to connect to the Docker Engine, retrying as many times as needed.

Then, the flow continues in the following, infinite loop:
* get *running* containers from `Containers` class
* if needed, collect metrics according to `METRICS_COLLECTION_INTERVAL`, using `MAX_COLLECTOR_THREADS` to make it faster
* if new metrics were collected:
    * update metrics in ***metrics_exporter.py*** so that Prometheus can scrape up-to-date values
    * update `LAST_METRICS_COLLECTED_AT_FILE` with new timestamp value
* sleep for `LOGS_COLLECTION_INTERVAL` (it is always <= `METRICS_COLLECTION_INTERVAL`) and then repeat the whole process again, as long as the program is alive


## How you can experiment it?

All you need is an ability to run Docker and most likely Linux-based system (might work on others also, but it is not guaranteed).

After a while, which can take some time - Docker might need to pull multiple base images from the net, you should run:
```
docker ps
```
and see:
```
CONTAINER ID   IMAGE             COMMAND                  CREATED              STATUS              PORTS                                                 NAMES
6e9142386269   metrics-collector   "python3 -u collecto…"   5 seconds ago    Up 4 seconds    0.0.0.0:9103->9103/tcp, :::9103->9103/tcp         metrics-collector
```

Just a few containers to play with. 

### Prometheus

We will expose metrics to Prometheus, so after running above commands, you should be able to go to http://localhost:9103/metrics and see the metrics exported. We have prometheus running already in our existing environment so we will use that one to configure alerts and Grafana. We have to make sure connectivity in between our Prometheus server and Docker Box Server. After making connectivity we have to add the scraping job in the prometheus.yml file:

```
  - job_name: 'containers'
    scrape_interval: 30s
    static_configs:
      - targets: ['<ip-of-docker-machine:9103>']
```
Then we have to restart the prometheus, After restarting prometheus we can run below given query on prometheus to verify:

```
{__name__=~"container.+"}
```

It should give empty results for now, but most of the exposed by the tool metrics will be available here.

### Collector

As of now, we know how *collector* works and where we should expect containers metrics, collected by it. Let's then start the *collector*! 
From the root folder (*metrics-collector*) run:
```
./build.sh
```
After a while, you should run:
```
docker ps
```
and see:
```
CONTAINER ID   IMAGE                        COMMAND                  CREATED          STATUS          PORTS                                                 NAMES
6e9142386269   metrics-collector   "python3 -u collecto…"   5 seconds ago    Up 4 seconds    0.0.0.0:10101->10101/tcp, :::10101->10101/tcp         metrics-and-logs-collector
```

If you are curious, you can run:
```
docker logs metrics-collector
```
And see something similar to:
```
...

2024-02-12 17:14:53.070 [INFO] collector: Checking containers...
2024-02-12 17:14:53.082 [INFO] collector: To check containers: ['metrics-collector: 4fa4be087200b854aa02a40212b7e1f0ea96d9662d489d9e76d4114be84a9cc2', 'logs-browser: c9082e429507c23252b41abee694b30584e1e2013a2817e04860aa955458af07', 'some-custom-app: a9aea1bc4420a5d0002e6246b218db1dc2e16cfa9ef0dd967317a1c23a8f0268', 'prometheus: 8072263ab5373dc3269d561b4349734ac2a9782a44e0c5f575d54f357a1de4d7', 'postgres-db: e9208517aaacbaef2bbc7edb6a40058051ca367e7f4bf26931e7c85774e2bec9']
2024-02-12 17:14:53.082 [INFO] containers: Have 5 running containers, checking their metrics/stats...
2024-02-12 17:14:55.103 [INFO] containers: 
Metrics checked.

2024-02-12 17:14:55.103 [INFO] collector: Updating last-data-read-at file: /tmp/last-metrics-collected-at.txt
2024-02-12 17:14:55.103 [INFO] containers: Have 5 running containers, checking their logs...
2024-02-12 17:14:55.134 [INFO] containers: 
Logs checked.

2024-02-12 17:14:55.134 [INFO] collector: Updating last-data-read-at file: /tmp/last-logs-collected-at.txt
2024-02-12 17:14:55.135 [INFO] collector: 
Sleeping for 5s...

```
...which means that the *collector* is running and collecting. 

Running Prometheus query (http://localhost:9090):
```
{__name__=~"container.*"}
```
should give you loads of metrics like these:
```
container_cpu_usage_percent{container="logs-browser", instance="localhost:10101", job="metrics-and-logs-collector", machine="local-machine"}
0
container_cpu_usage_percent{container="metrics-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
0.0039
container_cpu_usage_percent{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
0
container_cpu_usage_percent{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
0.0001
container_cpu_usage_percent{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
2.0063
container_cpus_available{container="logs-browser", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
0.25
container_cpus_available{container="metrics-and-logs-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
0.5
container_cpus_available{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1
container_cpus_available{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1
container_cpus_available{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
12
container_logs_created{container="metrics-collector", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
1707758095.1165588
container_logs_created{container="postgres-db", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
1707758117.280608
container_logs_created{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="error", machine="local-machine"}
1707758095.1268246
container_logs_created{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
1707758100.168529
container_logs_created{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="warning", machine="local-machine"}
1707758161.573784
container_logs_total{container="metrics-collector", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
21
container_logs_total{container="postgres-db", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
1
container_logs_total{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="error", machine="local-machine"}
13
container_logs_total{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="info", machine="local-machine"}
7
container_logs_total{container="some-custom-app", instance="localhost:10101", job="metrics-collector", level="warning", machine="local-machine"}
1
container_max_memory_bytes{container="logs-browser", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
262144000
container_max_memory_bytes{container="metrics-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
262144000
container_max_memory_bytes{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
524288000
container_max_memory_bytes{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
262144000
container_max_memory_bytes{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
33561669632
container_started_at_timestamp_seconds{container="logs-browser", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707757813
container_started_at_timestamp_seconds{container="metrics-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758092
container_started_at_timestamp_seconds{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707757808
container_started_at_timestamp_seconds{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707757810
container_started_at_timestamp_seconds{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707757812
container_up_timestamp_seconds{container="logs-browser", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758205
container_up_timestamp_seconds{container="metrics-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758204
container_up_timestamp_seconds{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758205
container_up_timestamp_seconds{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758205
container_up_timestamp_seconds{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
1707758205
container_used_memory_bytes{container="logs-browser", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
20320256
container_used_memory_bytes{container="metrics-collector", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
31956992
container_used_memory_bytes{container="postgres-db", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
115363840
container_used_memory_bytes{container="prometheus", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
104755200
container_used_memory_bytes{container="some-custom-app", instance="localhost:10101", job="metrics-collector", machine="local-machine"}
26755072
```

Additionally, all Prometheus alerts should be soon off, which you can see by clicking *Alerts* on the Prometheus UI. 

We can also run:
```
docker stats
```
to see stats of various containers:
```
CONTAINER ID   NAME                         CPU %     MEM USAGE / LIMIT     MEM %     NET I/O         BLOCK I/O         PIDS
4fa4be087200   metrics-collector            0.01%     26.23MiB / 250MiB     10.49%    51kB / 70.3kB   10.3MB / 2.17MB   7
```
What's worth noting is that *metrics-collector* keeps its CPU and MEM usage extremely low on all times :)
