#!/bin/bash

CONTAINER_NAME="myfirstcontainer"
<<<<<<< HEAD
LXC_IMAGE="ubuntu:jammy"
=======
COMPOSE_FILE=$1
>>>>>>> e04a09462631b2289bc0f68526628a3fa82c9d3a
STORAGE_POOL="docker"

if [[ -z "$(ls $1)" ]]; then
	echo "A compose file must be passed as the first argument" >&2
	exit -1
fi

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
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get update"
	lxc exec $CONTAINER_NAME -- bash -c "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
}

clean_docker() {
	docker stop $(docker ps -a -q)
	docker rm $(docker ps -a -q)
	docker image prune -f
}

clean_docker_containers() {
	docker stop $(docker ps -a -q)
	docker rm $(docker ps -a -q)
}

restart_docker() {
	lxc exec $CONTAINER_NAME -- bash -c '$(declare -f clean_docker_containers); clean_docker_containers'
	# lxc exec $CONTAINER_NAME -- bash -c "docker run -d $DOCKER_NAME"
}

reinit_docker() {
	lxc exec $CONTAINER_NAME -- bash -c '$(declare -f clean_docker); clean_docker'
	lxc exec $CONTAINER_NAME -- bash -c "docker load -i /root/web/$DOCKER_FILE"
}

load_file() {
	lxc file push ./$1 $CONTAINER_NAME/root/
	lxc exec $CONTAINER_NAME -- bash -c 'for container in $(docker ps -q); do \
		docker container stop $container; \
		docker container rm $container; \       		
		done'
	lxc exec $CONTAINER_NAME -- bash -c 'docker images | awk "{print $1}" | while read imageId; do \
		if [[ $imageId != "IMAGE" ]]; then
			docker rmi "$imageId"; \
		fi
		done'
	lxc exec $CONTAINER_NAME -- bash -c 'for file in $(ls /root/containers/); do \
		docker load -i /root/containers/$file; \
		done'
	lxc exec $CONTAINER_NAME -- bash -c "cd /root/containers/ | docker-compose up"
}

load_container_file() {
	lxc file push $1 $CONTAINER_NAME/root/containers
}

exist_lxc_image() {
	if [ $(lxc image list "$LXC_IMAGE" | wc -l) -gt 3 ]; then
    	return 0
	else
		return 1
	fi
}

build () {
    if ! exist_lxc_image; then
        echo "LXC image ($LXC_IMAGE) does not exist."
        return 1
    fi
    if lxc list | grep -q "^| $CONTAINER_NAME "; then
        echo "Stopping and deleting current instance."
        lxc stop $CONTAINER_NAME
        lxc delete $CONTAINER_NAME
    fi
    lxc launch $LXC_IMAGE $CONTAINER_NAME 
    install_docker
    restart_docker
	lxc exec $CONTAINER_NAME -- bash -c 'mkdir /root/containers'
	echo "Setting the docker-compose file"
	lxc file push $COMPOSE_FILE $CONTAINER_NAME:/root/containers/docker-compose.yaml --force
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
	echo "USAGE: "
	echo "lxcops.sh {docker-compose.yaml file path} [-n name] [-l .tar.gz_file_path] [-s [config_file_path]] []"
	echo "A 'docker-compose.yaml' must be passed as the first argument. This file must define which containers to run and how to start them." 
	echo ""
	echo "Commands:"
	echo "  -n {name}  Sets the container name to {name}."
	echo "  -b 	Builds the LXC container and overrides it in case it already exists. It also starts the lxc container. This command will remove all uploaded docker container images."
	echo "  -s [config file path]  Starts the LXC container without cleaning the current container (that is, without overriding it). A configuration file can also be specified. "
	echo -n "This command will restart all docker containers."
	echo "  -l {.tar.gz file path}  Uploads a container image exported as a .tar.gz file into the LXC container's /root/containers folder."
	echo "  -r	Restarts all docker containers inside the LXC container and reloads all docker images."
	echo "  -h  Prints this help"
	echo ""
}

while getopts "bs:rl:n:h" arg; do
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
			echo "Uploading the $OPTARG container image file into the LXC container."
			load_container_file
			;;
		n)
			CONTAINER_NAME=$OPTARG
			echo "LXC Container name set to $OPTARG"
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