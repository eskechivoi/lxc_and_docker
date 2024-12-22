# LxcDevOps

This repository contains a script that enables easy configuration of docker inside LXC containers. This script abstracts from having to create the volumes for the docker containers, copying files or other rutinary tasks.

# Release plan

## Version 0.1
- Define new `.yaml` format that defines the containers to be run inside the LXC container.
  - This format MUST allow Dockerfile support -> "dockerfile": "<path_to_dockerfile>"
  - This format acts as a wrapper for a docker compose file. 
  - If a dockerfile is defined in the `.yaml`, then that dockerfile will be used as the image defined in the compose file.
- Support for different LXC images.
- Possibility to link docker volumes with LXC volumes.
- Dockerfile support
- Docker image support
- Migrate help script and data parse to python. Keep the container management in bash.