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

if [[ -z "$(ls $1)" ]]; then
    echo "A compose file must be passed as the first argument" >&2
    exit -1
fi
