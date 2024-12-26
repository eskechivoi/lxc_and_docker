import argparse
import logging
import os
import select
import sys
import subprocess
from typing import Optional

LOGGER = logging.getLogger()
SUPPORTED_SHELLS = ["/bin/bash"]


def get_lxc_version() -> Optional[str]:
    try:
        resultado = subprocess.run(
            ["lxc", "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return resultado.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_shell():
    shell_path = os.getenv("SHELL", None)
    if not shell_path:
        shell_path = os.path.isfile("/bin/sh")

    if not shell_path or shell_path not in SUPPORTED_SHELLS:
        LOGGER.error("This script is not currently supporting your shell.")
        sys.exit(-1)
    else:
        shell = os.path.basename(shell_path)
        return shell, shell_path


def call_bash_function(function_name, *args):
    version = get_lxc_version()
    if not version:
        LOGGER.error("LXC or LXD not correctly installed.")

    shell, shell_path = get_shell()
    command = f". ./{shell}.sh && {function_name} {' '.join(args)}"
    LOGGER.debug("Executing: '%s'", command)

    process = subprocess.Popen(
        [f"{shell_path}", "-c", command],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=subprocess.DEVNULL,
        text=True,
        env=os.environ,
    )

    while not process.poll():
        rlist, _, _ = select.select([process.stdout, process.stderr], [], [], 1)

        for stream in rlist:
            line = stream.readline()
            if not line:
                break

            if stream is process.stdout:
                LOGGER.info(line.strip())
            else:
                LOGGER.error(line.strip())

    process.stdout.close()
    process.stderr.close()
    process.wait()

    if process.returncode != 0:
        LOGGER.error(
            "Command '%s' returned non-zero exit status %s.",
            command,
            process.returncode,
        )


def conf_logger(verbose=False):
    LOGGER.setLevel(logging.DEBUG)

    stdout_handler = logging.StreamHandler(sys.stdout)
    if verbose:
        stdout_handler.setLevel(logging.DEBUG)
    else:
        stdout_handler.setLevel(logging.INFO)

    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setLevel(logging.ERROR)

    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    stdout_handler.setFormatter(formatter)
    stderr_handler.setFormatter(formatter)

    LOGGER.addHandler(stdout_handler)
    LOGGER.addHandler(stderr_handler)


def conf_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Operate the LXC container. "
        "This script MUST be run in a Linux distribution as root. "
        "For this script to work, you must have bash installed on your system.",
        epilog="Developed by Fernando Rodríguez @eskechivoi - GNU GPL v3.0",
    )
    parser.add_argument(
        "compose_file",
        help="Defines the configuration of the docker containers. A 'docker-compose.yaml' "
        "must be passed as the first argument.",
    )
    parser.add_argument("-n", "--name", help="The LXC container name to {name}.")
    parser.add_argument("-i", "--image", help="The LXC image to use.")
    parser.add_argument(
        "-b",
        "--build",
        action="store_true",
        help="Builds the LXC container and overrides it in case it already exists. "
        "It also starts the lxc container. This command will remove all uploaded docker container images.",
    )
    parser.add_argument(
        "-s",
        "--start",
        metavar="CONFIG_FILE",
        nargs="?",
        const=True,
        help="Starts the LXC container without cleaning the current container "
        "(that is, without overriding it). A configuration file can also be specified.",
    )
    parser.add_argument(
        "-l",
        "--load",
        metavar=".TAR.GZ",
        help="Uploads a container image exported as a .tar.gz file into the LXC container's "
        "/root/containers folder.",
    )
    parser.add_argument(
        "-r",
        "--restart",
        action="store_true",
        help="Restarts all docker containers inside the LXC container and reloads all docker images.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print the debug messages. It's set to False by default.",
    )
    return parser


def main():
    parser = conf_parser()
    args = parser.parse_args()
    conf_logger(verbose=args.verbose)

    if not os.path.isfile(args.compose_file):
        LOGGER.error(
            "A compose file must be passed as the first argument. This file must exist."
        )
        sys.exit(-1)
    os.environ["COMPOSE_FILE"] = args.compose_file

    if args.name:
        os.environ["CONTAINER_NAME"] = args.name
        LOGGER.info(f"LXC Container name set to {args.name}")

    if args.image:
        os.environ["LXC_IMAGE"] = args.image
        LOGGER.info(f"LXC Image set to {args.image}")

    if args.build:
        call_bash_function("build")

    if args.start:
        call_bash_function("lxcstartc")

    if args.restart:
        call_bash_function("restart_docker")

    if args.load:
        name = os.path.splitext(os.path.basename(args.load))[0]
        call_bash_function("load_container", args.load, name)


if __name__ == "__main__":
    main()
