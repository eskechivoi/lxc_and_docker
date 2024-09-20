# LxcDevOps

This repository contains a script that enables easy configuration of LXC containers that use docker inside them. This script abstracts from having to create the volumes for the docker containers, copying images and managing docker inside the LXC container.

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