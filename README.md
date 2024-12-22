# Easily use Docker containers inside LXC containers

This repository contains a script that enables easy configuration of docker inside LXC containers. This script abstracts from having to create the volumes for the docker containers, copying images and managing docker inside the LXC container.

**IMPORTANT**: Currently, docker containers inside the LXC Container are orquestrated using a docker compose file. This docker compose file MUST define which docker containers should be started and how. 

# Example of infrastructure

```mermaid
block-beta
    columns 3
    Host:3
    LXCContainer1 ... LXCContainerN
    space:3
    DockerContainer1 DockerContainer2 DockerContainerN
    LXCContainer1 --> DockerContainer1
    LXCContainer1 --> DockerContainer2
    LXCContainerN --> DockerContainerN
```

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
