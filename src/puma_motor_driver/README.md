This package is excerpted from https://github.com/clearpathrobotics/clearpath_robot/tree/jazzy
to address one temporary specific issue as follows.

When the platform velocity controller is deactivated, ros2 control sends NaNs to the 
driver. The Puma driver forwards these to the motor controller, which spins the wheels at
maximum velocity. We have made a ros2control MR to send zeroes instead
(https://github.com/ros-controls/ros2_controllers/pull/2578).
In the meantime, we intercept the NaNs in the driver and subsitute zeroes.

The original README.md from the Clearpath parent project is included here as 
README.clearpath_robot.md along with the original LICENSE.
