# build stage
FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ROS_DISTRO=jazzy

# configurable via .env but with sensible defaults for production
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=franka

# install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# create non-root user without sudo
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> /home/$USERNAME/.bashrc \
    && echo "source /ros2_ws/install/setup.bash" >> /home/$USERNAME/.bashrc

USER $USERNAME

# install only runtime dependencies
RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
    ros-jazzy-controller-manager \
    ros-jazzy-joint-state-broadcaster \
    ros-jazzy-joint-trajectory-controller \
    ros-jazzy-moveit \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

WORKDIR /ros2_ws

# copy source and import additional repos
COPY --chown=$USERNAME:$USERNAME . /ros2_ws/src
# RUN vcs import src < src/franka.repos --recursive --skip-existing
RUN git clone --branch 2.1.0 --recursive https://github.com/frankarobotics/franka_description.git src/franka_description
RUN git clone --branch 0.18.0 --recursive https://github.com/frankarobotics/libfranka.git src/libfranka

RUN sudo apt-get update

# install dependencies, skipping the packages we just imported
RUN rosdep update \
    && rosdep install --from-paths src --ignore-src --rosdistro $ROS_DISTRO -y \
    --skip-keys="libfranka franka_description" \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# build the workspace
RUN /bin/bash -c ". /opt/ros/$ROS_DISTRO/setup.bash && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"

COPY --chown=$USERNAME:$USERNAME ./franka_entrypoint.sh /franka_entrypoint.sh
RUN chmod +x /franka_entrypoint.sh

WORKDIR /ros2_ws

ENTRYPOINT [ "/franka_entrypoint.sh" ]
CMD [ "/bin/bash" ]
