#!/bin/bash

CONTAINER_NAME="myfirstcontainer"
STORAGE_POOL="docker"

install_docker() {
	if sudo lxc storage list | grep -q "^| $STORAGE_POOL"; then
		lxc storage volume delete $STORAGE_POOL $CONTAINER_NAME
		lxc storage delete $STORAGE_POOL
	fi
	lxc storage create $STORAGE_POOL btrfs
	lxc storage volume create $STORAGE_POOL $CONTAINER_NAME
	lxc config device add $CONTAINER_NAME $STORAGE_POOL disk pool=$STORAGE_POOL source=$CONTAINER_NAME path=/var/lib/docker
	lxc config set $CONTAINER_NAME security.nesting=true security.syscalls.intercept.mknod=true security.syscalls.intercept.setxattr=true
	lxc restart $CONTAINER_NAME
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get update"
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get install -y \
		ca-certificates \
		curl \
		gnupg \
		lsb-release"
	lxc exec $CONTAINER_NAME -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg \
		--dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
	lxc exec $CONTAINER_NAME -- bash -c 'echo \ 
		"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
		| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

	lxc exec $CONTAINER_NAME -- bash -c 'echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
		| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get update"
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
}

restart_docker() {
	lxc exec $CONTAINER_NAME -- bash -c 'for container in $(docker ps -q); do \
		docker container stop $container; \
		docker container rm $container; \       		
		done'
	# lxc exec $CONTAINER_NAME -- bash -c "docker image rm $DOCKER_NAME"
	# lxc exec $CONTAINER_NAME -- bash -c "docker load -i /root/web/$DOCKER_FILE"
	# lxc exec $CONTAINER_NAME -- bash -c "docker run -d $DOCKER_NAME"
}

load_file() {
	lxc file push ./$1 $CONTAINER_NAME/root/
}

build () {
	if lxc list | grep -q "^| $CONTAINER_NAME "; then
		echo "Stopping and deleting current instance."
		lxc stop $CONTAINER_NAME
		lxc delete $CONTAINER_NAME
	fi
	lxc launch ubuntu:jammy $CONTAINER_NAME 
	install_docker
	restart_docker
}

lxcstartc () {
    if [[ "$1" ]]; then 
        lxc-start -n $CONTAINER_NAME
    else
        lxc-start -n $CONTAINER_NAME -f $1 
    fi
}

print_help() {
	echo "Operate the SUGUS web LXC container. This script MUST be run as root."
	echo ""
	echo "Commands:"
    echo "  -n {name}  Sets the container name to {name}."
	echo "  -b 	Builds the LXC container and overrides it in case it already exists. It also starts the lxc container"
	echo "  -s [config_file_path]  Starts the LXC container without cleaning the current container (that is, without overriding it). A configuration file can also be specified."
	echo "  -l	Uploads a container image exported as a .tar.gz file into the LXC container's /root/containers folder."
	echo "  -r	Restarts all docker containers inside the LXC container."
	echo ""
}

while getopts "bshrn:" arg; do
	case $arg in
		b)
			echo "Building the LXC container. This will override the container in case it already exists..."
			build	
			;;
		s)
			echo "Starting the LXC container..."
			lxcstartc
			;;
		r)
			echo "Restarting the docker containers inside the LXC container."
			restart_docker
			;;
		l)
			echo "Uploading the $OPTARG file into the LXC container."
			load_file
			;;
        n)
            CONTAINER_NAME=$OPTARG
            echo "Container name set to $OPTARG"
            ;;
		h)
			print_help
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			print_help
			;;
	esac
done