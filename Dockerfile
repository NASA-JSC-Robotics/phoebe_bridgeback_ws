# Set desired ROS distribution, this image currently only supports humble.
ARG ROS_DISTRO=humble

# Using the pre-compiled ROS images as the base.
FROM ros:${ROS_DISTRO} AS er4-dev

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Overridable non root user information, this can be annoying for non humble
# ROS base images.
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=er4-user

# Define the install location for the developing application
ENV ER4_WS="/home/er4-user/ws"

# DEBIAN_FRONTEND is set as an ARG instead of ENV variable so it doesn't persist in the image after build
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -q -y \
    bash-completion \
    ccache \
    gdb \
    gdbserver \
    git \
    python3-colcon-clean \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-pip \
    python3-rosdep \
    python3-vcstool \
    software-properties-common \
    terminator \
    tmux \
    vim \
    xterm \
    wget

# Setup the install directory and clone the workspace to it
# We put the install into the `${CLR_WS}` directory in typical ROS fashion
RUN mkdir -p ${ER4_WS}
WORKDIR  ${ER4_WS}
RUN mkdir src build install log

# We copy in source prior to installing rosdeps. However, we could alternatively just copy in package manifests,
# install rosdeps, then copy in the remainder of the source to preserve the cache if we ever feel that this
# is slow or onerous.
COPY src/ src/

# Add clearpath rosdeps and apt packages so that we can pull non-ros-standard clearpath ros packages
RUN wget -q https://raw.githubusercontent.com/clearpathrobotics/public-rosdistro/master/rosdep/50-clearpath.list \
    -O /etc/ros/rosdep/sources.list.d/50-clearpath.list && \
    wget https://packages.clearpathrobotics.com/public.key -O - | sudo apt-key add - && \
    sudo bash -c 'echo "deb https://packages.clearpathrobotics.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/clearpath-latest.list'

# Install rosdeps
# Init is unnecessary if using the ROS base image
# RUN sudo rosdep init && rosdep update --rosdistro ${ROS_DISTRO}
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    apt-get update && \
    rosdep update && \
    rosdep install -iy --from-paths src

# Install extra ROS deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -q -y \
    ros-${ROS_DISTRO}-ros2controlcli \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    ros-${ROS_DISTRO}-rmw-fastrtps-cpp

# Add a non-root user with provided user details
RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -l -u ${USER_UID} -g ${USER_GID} --create-home -m -s /bin/bash -G sudo,adm,dialout,dip,plugdev ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p \
        /home/${USERNAME}/.ccache \
        /home/${USERNAME}/.colcon \
        /home/${USERNAME}/.ros && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}

# Setup colcon default mixins and add default settings
RUN colcon mixin add default \
    https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update || true
RUN colcon metadata add default  \
    https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update || true

COPY config/colcon-defaults.yaml /home/${USERNAME}/.colcon/defaults.yaml

# Fix rosdep permissions and ensure sudo while we're at it
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sudo apt update && \
    . /opt/ros/${ROS_DISTRO}/setup.bash && \
    rosdep update --rosdistro ${ROS_DISTRO}

# Setup entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN echo "source /entrypoint.sh" >> ~/.bashrc
ENTRYPOINT ["/entrypoint.sh"]

# Source built dev image for automated testing.
FROM er4-dev AS er4-dev-source

ARG USERNAME

RUN . /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build
