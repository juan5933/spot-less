classdef SpotlessMain < handle
    % Main class to handle the execution of the robot's tasks, environment setup,
    % and point cloud simulation. It contains methods to run the simulation and 
    % generate the workspace point cloud.

    methods (Static)
        function Run()
            % Run the main simulation for the robot task.
            % This method sets up the environment, bricks, gripper, and robot,
            % then executes the robot's trajectory while profiling the execution.
            
            % Clear the current figure and reset profiling data
            clf;  % Clear the current figure window
            
            % Set up the environment and bricks
            EnvironmentSetup();  % Create and display the environment
            plates = Plates();  % Initialize the Plates object
            plates.PlacePlates();  % Place the plates in the environment
            
            % Set up the gripper
            gripper = Gripper();  % Initialize the Gripper object
            
            % Set up the robot
            robot = UR16e();  % Initialize the robot (Linear UR3e model)
            
            % Set up and run the robot trajectory, passing the robot, bricks, and gripper
            trajectory = SpotlessTrajectory(robot, plates, gripper);  % Initialize RobotTrajectory
            trajectory.Run();  % Execute the robot's movement trajectory
            
        end


    end
end