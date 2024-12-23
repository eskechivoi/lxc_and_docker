#!/bin/bash

CONTAINER_NAME="${CONTAINER_NAME:-myfirstcontainer}"
COMPOSE_FILE="${COMPOSE_FILE:-./docker-compose.yaml}"
STORAGE_POOL="${STORAGE_POOL:-docker}"

if [[ -z "$(ls $1)" ]]; then
	echo "[*] A compose file must be passed as the first argument" >&2
	exit -1
fi

# Execute a command inside the LXC container.
# Params:
# 	$1: The command to execute.
execute_command_in_lxc() {
	lxc exec $CONTAINER_NAME -- bash -c "$1"
}

# Installs docker inside the LXC container.
# Environment variables:
# 	$STORAGE_POOL: The name of the storage pool.
# 	$CONTAINER_NAME: The name of the LXC container.	
install_docker() {
	echo "[-] Deleting previous volumes for docker."
	if lxc storage list | grep -q "^| $STORAGE_POOL"; then
		lxc storage volume delete $STORAGE_POOL $CONTAINER_NAME
		lxc storage delete $STORAGE_POOL
	fi
	echo "[-] Creating and attaching a volume for docker."
	lxc storage create $STORAGE_POOL btrfs
	lxc storage volume create $STORAGE_POOL $CONTAINER_NAME
	lxc config device add $CONTAINER_NAME $STORAGE_POOL disk pool=$STORAGE_POOL source=$CONTAINER_NAME path=/var/lib/docker
	echo "[-] Setting the security policy for docker."
	lxc config set $CONTAINER_NAME security.nesting=true security.syscalls.intercept.mknod=true security.syscalls.intercept.setxattr=true
	echo "[-] Restarting LXC container."
	lxc restart $CONTAINER_NAME
	echo "[-] Installing docker..."
	execute_command_in_lxc "apt-get update"
	execute_command_in_lxc "apt-get install -y \
		ca-certificates \
		curl \
		gnupg \
		lsb-release"
	execute_command_in_lxc "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg \
		--dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
	execute_command_in_lxc '
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
		https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
		tee /etc/apt/sources.list.d/docker.list > /dev/null'
	execute_command_in_lxc "apt-get update"
	execute_command_in_lxc "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
	echo "[-] Finished installing docker."
}

lxc_docker_run() {
	echo "[+] Running docker compose"
	execute_command_in_lxc "cd /root/yaml | docker-compose up"
}

lxc_docker_build_and_run() {
	execute_command_in_lxc 'source /root/ops_in_lxc.sh; build_docker_images /root/containers'
	lxc_docker_run
}

# Stops and removes all containers and starts all containers again from the .yaml file.
# Params:
# 	$1: .yaml file from which to start the containers.
# Environment variables:
#	$CONTAINER_NAME: Name of the LXC container.
restart_docker_containers() {
	execute_command_in_lxc 'source /root/ops_in_lxc.sh; docker_stop_and_remove_all'
	lxc_docker_run
}

# Cleans all Docker resources and builds and executes Docker again in the LXC container.
reinitialize_docker() {
	execute_command_in_lxc 'source /root/ops_in_lxc.sh; docker_clean_all_resources'
	lxc_docker_build_and_run
}

# Loads a file into a route in the LXC container.
# Params:
#	$1: The file name (in the local FS).
#	$2: The route inside the LXC container. (including the file name)
# Environment variables:
#	$CONTAINER_NAME: The name of the LXC container.
load_file() {
	echo "[+] Loading file '$1' from host FS into '$2'"
	execute_command_in_lxc "if [ ! -d '$2' ]; then
		mkdir -p $(dirname $2)
		fi"
	execute_command_in_lxc "rm -f $2"
	lxc file push ./$1 $CONTAINER_NAME$2
}

# Uploads a new docker compose file.
# If there's already a docker compose file in the LXC container,
# it is overwritten by the new one.
# Params:
# 	$1: The file path in the host's FS.
load_yaml_file() {
	load_file $1 "/root/yaml/docker-compose.yaml"
}

# Uploads a .tar.gz to build a new container, adding the name of the image.
# Params:
# 	$1: The path to the .tar.gz file in the host FS.
#		This file must contain a Dockerfile to build the image.
#	$2: The docker image name.
load_container() {
	load_file $1 "/root/containers/$1"
	if [ ! -d "/root/containers/$2" ]; then
		mkdir "/root/containers/$2"
	fi
}

# Evaluates whether the LXC image exists.
# Param: 
# 	$1: The LXC image.
# Returns:
#	0: The LXC image exists.
#	1: Otherwise.
exists_lxc_image() {
	if [ $(lxc image list "$1" | wc -l) -gt 3 ]; then
    	return 0
	else
		return 1
	fi
}

# Stops and deletes the LXC container
# Params:
#	$1: The container name.
lxc_stop_and_delete() {
	if lxc list | grep -q "^| $1 "; then
        echo "[+] Stopping and deleting current instance."
        lxc stop $1
        lxc delete $1
    fi
}

build () {
    if ! exists_lxc_image $LXC_IMAGE; then
        echo "[*] LXC image ($LXC_IMAGE) does not exist." >&2
        return 1
    fi
    lxc_stop_and_delete $CONTAINER_NAME
    lxc launch $LXC_IMAGE $CONTAINER_NAME 
    install_docker
	echo "[+] Installing configuration scripts..."
	load_file './ops_in_lxc.sh' '/root/ops_in_lxc.sh'
	echo "[+] Setting the docker-compose file"
	load_yaml_file $COMPOSE_FILE
	reinitialize_docker
}

lxcstartc () {
	if [[ "$1" ]]; then 
		lxc-start -n $CONTAINER_NAME
	else
		lxc-start -n $CONTAINER_NAME -f $1 
	fi
}

# Returns the name of a .tar.gz file without the extension.
# As an input, it accepts a path.
# Params:
#	$1: The .tar.gz file path.
# Returns:
# 	The filename without extension.
get_tar_name_without_extension() {
	local filepath="$1"
	local filename=$(basename "$filepath")
	echo "${filename%%.*}"
}
