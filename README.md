# Container-Metrics
Simple Python app/tool that collects metrics and logs from Docker Containers.

It then exposes those metrics to Prometheus (which just means having an http endpoint) and saves logs in the local file system, limiting their size and rotating files, if necessary (it's also pretty straightforward to save logs somewhere else, in a database for example).

Basic requirements:

Python 3.10, compatible pip & deps specified in src/requirements.txt
Alternatively just Docker and running it as a container - see build_and_run_collector.bash
Prometheus, if you want to make practical use of the exposed metrics
