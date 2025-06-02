# Set desired ROS distribution, this image currently only supports humble.
ARG ROS_DISTRO=humble

# Using the pre-compiled ROS images as the base.
FROM ros:${ROS_DISTRO} AS er4-dev

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Overridable non root user information, this can be annoying for non humble ROS base images, which
# may already have a non-root user created.
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=er4-user

# Define the install location for the developing application
ENV ER4_WS="/home/er4-user/ws"

# DEBIAN_FRONTEND is set as an ARG instead of ENV variable so it doesn't persist in the image after build
ARG DEBIAN_FRONTEND=noninteractive

# TODO: Remove this when the base images are fixed, as they currently have expired apt keys.
# https://github.com/docker-library/official-images/pull/19162
RUN rm /etc/apt/sources.list.d/ros2-latest.list \
&& rm /usr/share/keyrings/ros2-latest-archive-keyring.gpg

RUN apt-get update \
&& apt-get install -y ca-certificates curl

RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') ;\
  curl -L -s -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" \
  && apt-get update \
  && apt-get install /tmp/ros2-apt-source.deb \
  && rm -f /tmp/ros2-apt-source.deb
# END: TODO

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -q -y \
    bash-completion \
    ccache \
    gdb \
    gdbserver \
    git \
    less \
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

# Add a non-root user with provided user details
RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -l -u ${USER_UID} -g ${USER_GID} --create-home -m -s /bin/bash -G sudo,adm,dialout,dip,plugdev,video ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p \
        /home/${USERNAME}/.ccache \
        /home/${USERNAME}/.colcon \
        /home/${USERNAME}/.ros \
        ${ER4_WS}

# Setup the install directory and copy the workspace to it.
# We could alternatively copy package manifests to preserve the layer cache if the build duration becomes too onerous.
WORKDIR  ${ER4_WS}
RUN mkdir src build install log
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

RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

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

# Setup entrypoint and ensure it's added to ~/.bashrc
COPY scripts/entrypoint.sh /entrypoint.sh
RUN echo "source /entrypoint.sh" >> ~/.bashrc

# Make it obvious when operating in a container
RUN echo "PS1=\"${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\](docker):\[\033[01;34m\]\w\[\033[00m\]\$ \"" >> ~/.bashrc

ENTRYPOINT ["/entrypoint.sh"]

# Source built dev image for automated testing.
FROM er4-dev AS er4-dev-source

ARG USERNAME

RUN . /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build
