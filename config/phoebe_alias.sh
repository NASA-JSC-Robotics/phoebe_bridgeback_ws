alias reset_grippers='ros2 service call /right_robotiq_activation_controller/reactivate_gripper std_srvs/srv/Trigger; ros2 service call /left_robotiq_activation_controller/reactivate_gripper std_srvs/srv/Trigger'
alias camera_trigger_right='ros2 service call /right_wrist_mounted_camera/request_images std_srvs/srv/Trigger'
alias camera_trigger_left='ros2 service call /left_wrist_mounted_camera/request_images std_srvs/srv/Trigger'
