#!/bin/bash

# This script must be copied into the LXC container. 

# Builds a docker image, and names the image after the name of the folder.
# Params:
#	$1: The base path where all the dockerfile subfolders are.
build_docker_images() {
    for dir in "$1"/*/; do
        if [ -d "$dir" ]; then
            local container_name=$(basename "$dir")
			tar -xzvf $dir/*.tar.gz -C $dir/
            docker build -t "$container_name" "$dir"
        fi
    done
}

# Stops and removes all containers.
docker_stop_and_remove_all() {
    running_containers=$(docker ps -q)
    if [ -n "$running_containers" ]; then
        docker stop $running_containers
    fi
    all_containers=$(docker ps -a -q)
    if [ -n "$all_containers" ]; then
        docker rm $all_containers
    fi
}


# Stops and removes all containers.
# It also removes all docker images.
docker_clean_all_resources() {
	docker_stop_and_remove_all
	docker image prune -f
	# docker rmi $(docker images -q)
}