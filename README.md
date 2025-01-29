# Phoebe Bridgeback Workspace

Docker enabled ROS 2 workspace for building and running applications with the Phoebe Bridgeback robot.

## Quick Development Setup

1) [Install Docker](https://docs.docker.com/engine/install/ubuntu/)
    - Don't worry about Docker Desktop
    - For Ubuntu recommend using the [utility script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
2) Install git `sudo apt install git`
3) Clone this repo with submodules

    ```bash
    git clone --recursive git@js-er-code.jsc.nasa.gov:imetro/robots/phoebe-bridgeback/phoebe_bridgeback_ws.git
    cd phoebe_bridgeback_ws
    ```

    Or to update submodules if you do not do a recursive clone,

    ```bash
    cd phoebe_bridgeback_ws
    git submodule update --init
    ```

4) Set your user information for the project build
    - We recommend just putting this in your `~/.bashrc`:

      ```bash
      export USER_UID=$(id -u $USER)
      export USER_GID=$(id -g $USER)
      ```

    - Alternatively, open the `.env` file in the root of this repo and update each line with your information
        - `USER_UID` and `USER_GID`
            - found using `id -u` and `id -g` respectively

## Using the Images

Build the base images using the compose specification.

To build the development image from the repo root, and then launch it

```bash
# Compile the image
docker compose build

# Start it
docker compose up dev -d

# Connect to the console
docker compose exec dev bash
```

Once you're attached to the container, you can use it as a regular colcon workspace.
The contents of the `src/` directory will be mounted into `/home/er4-user/ws/src`.

### Other Things to Note

- Build logs, compiled artifaces, and the `.ccache` are also mounted in the workspace/user home.
This ensure artifacts are persisted even when restarting or recreating the container.

- Your host's DDS configuration (either cyclone or fastrtps) will be mounted into the image if set in your environment.
For more information refer to the [compose specification](docker-compose.yaml).

- Defaults for `colcon build` are set for the user. To change or modify, refer to the [defaults file](config/colcon-defaults.yaml).

- Two samples for GitLab CI for either [git submodules](.gitlab-ci.yml.submodules) or [vcs workspace](gitlab-ci.yml.vcs) are included.
Depending on your workflow, pick on and move it to `.gitlab-ci.yml` and it should build and push images, and run tests.
  - *NOTE:* There MUST be a `project.repos` file in the repo root to work with the VCS CI template.
