classdef RobotTrajectory < handle
    % This class handles the robot's movement trajectory for picking up and
    % dropping off bricks. It computes inverse kinematics, checks position error
    % tolerance, and animates both the robot and gripper.

    properties
        robot              % The robot instance
        steps              % Number of steps for smooth trajectory
        qStart             % Initial joint configuration
        bricks             % Instance of the Bricks class for access to brick positions
        text_h             % Text handle for displaying pose info
        gripper            % Instance of the Gripper class
        desiredPose        % Desired pose based on transformation matrix
        actualPose         % Actual pose after inverse kinematics
        positionError      % Difference between desired and actual pose
        tolerance = 0.005; % Tolerance for position error (5mm)
        qEnd               % Final joint configuration from inverse kinematics
        tActual            % Transformation matrix of the actual end-effector pose
    end

    methods
        function self = RobotTrajectory(robot, bricks, gripper)
            % Constructor to initialize the robot, number of steps, starting configuration, bricks, and gripper
            self.robot = robot;  % Assign the robot instance
            self.steps = 10;  % Set the number of steps for trajectory interpolation
            self.qStart = [-0.8 -pi 0 0 pi 0 0];  % Initial joint configuration
            self.bricks = bricks;  % Store the Bricks instance
            self.text_h = [];  % Initialize the text handle
            self.gripper = gripper;  % Store the Gripper instance
        end

        function Run(self)
            % Main function to perform the full trajectory of picking up and dropping off bricks.
            disp("STATUS: INITIALIZING ACTION")
            fprintf('\n');

            % Loop over all bricks to pick and place them
            for brickIndex = 1:9
                self.AbovePickupPoint();  % Move to the point above the brick's pickup position
                self.PickupBrick(brickIndex);  % Move to and pick up the brick
                self.AbovePickupPoint();  % Return to above the pickup point
                self.AboveDropoffZone();  % Move to the point above the drop-off zone
                self.ReleaseBrick(brickIndex);  % Drop the brick in the designated location
            end
            self.ReturnHome();  % Return the robot to the home position

            disp("STATUS: ACTION FINISHED")
            fprintf('\n');
        end



        
        function AbovePickupPoint(self)
            % Move to the first waypoint above the brick pickup point.
            disp("STATUS: MOVING TO HOME POSITION")
            fprintf('\n');

            % Define the desired transformation matrix (pose) above the pickup point
            t1 = transl([-0.75, 0.5, 0.5]) * rpy2tr(180, 0, 0, 'deg');
            self.qEnd = self.robot.model.ikcon(t1);  % Compute joint configuration using inverse kinematics


            % Compute actual joint state after inverse kinematics (ikcon)
            self.tActual = self.robot.model.fkine(self.qEnd).T;  % Get the transformation matrix of the current joint configuration
            self.desiredPose = t1(1:3, 4);  % Extract the desired end-effector position (x, y, z)
            self.actualPose = self.tActual(1:3, 4);  % Extract the actual end-effector position (x, y, z) from forward kinematics

            % Compute the position error between the desired and actual end-effector positions
            self.positionError = norm(self.desiredPose - self.actualPose);  % Euclidean distance between desired and actual positions

            % Check if the error is within the acceptable tolerance of 5mm
            if self.positionError <= self.tolerance
                disp('Pose satisfied within +- 5mm.');  % Display success message if within tolerance
            else
                disp('Pose does not meet the +-5mm tolerance.');  % Display warning if error exceeds tolerance
            end

            % Display the desired and actual poses for debugging/verification
            disp('Desired pose:');
            disp(self.desiredPose);

            disp('Actual pose:');
            disp(self.actualPose);

            % Display the computed position error in meters
            disp('Position error:');
            disp(self.positionError);

            % Generate a smooth trajectory between the current and desired joint configurations
            s = lspb(0, 1, self.steps);  % Generate a time vector using linear segment with parabolic blends (LSPB)
            path1 = nan(self.steps, 7);  % Preallocate the path array for the trajectory

            % Interpolate joint angles between qStart and qEnd for each step
            for j = 1:self.steps
                path1(j, :) = (1-s(j)) * self.qStart + s(j) * self.qEnd;  % Linear interpolation for each joint angle
            end

            % Animate the robot and gripper along the interpolated trajectory
            for j = 1:self.steps

                % Animate the robot movement for the j-th step
                self.robot.model.animate(path1(j, :));

                % Get the current transformation of the end-effector and adjust for gripper orientation
                Tr = self.robot.model.fkine(path1(j, :)).T * troty(-pi/2);

                % Animate the gripper with no delay (gripper movement in sync with the robot)
                self.gripper.robot.delay = 0;
                self.gripper.animateGripper(Tr);  % Move the gripper along with the robot's end-effector
                axis equal  % Keep equal axis proportions for proper visualization
                drawnow();  % Update the figure window in real-time
                pause(0.01);  % Add a small pause to control the animation speed

                % Delete the previously displayed text handle if it exists
                try delete(self.text_h); end  %#ok<TRYNC>

                % Compute and display the final transformation matrix at the last step
                Tr1 = self.robot.model.fkine(path1(size(self.steps, 1), :)).T;  % Get the transformation matrix at the final step
                try delete(Tr1); end  %#ok<TRYNC>  % Try to delete Tr1 if needed

                % Create a message displaying the final pose information
                message = sprintf([num2str(round(Tr1(1, :), 2, 'significant')), '\n' ...
                    num2str(round(Tr1(2, :), 2, 'significant')), '\n' ...
                    num2str(round(Tr1(3, :), 2, 'significant'))]);

                % Display the final pose as text on the plot
                self.text_h = text(0, 0, 3, message, 'FontSize', 10, 'Color', [.6 .2 .6]);  % Text display in purple color

                drawnow();  % Update the figure window to display the text
            end

            % Update the starting joint configuration to the final configuration for the next motion
            self.qStart = self.qEnd;
        end




        function PickupBrick(self, brickIndex)
            % Move to the brick's position and pick it up using brickStart from Bricks class
            disp("STATUS: MOVING TO BRICK");  % Display the current action
            fprintf('\n');  % New line for cleaner output

            % Generate the transformation to move above the brick's position
            t2 = transl(self.bricks.brickStart(brickIndex,:)) * rpy2tr(180,0,0,'deg');
            self.qEnd = self.robot.model.ikcon(t2);  % Calculate inverse kinematics to find joint configuration

            % Compute the actual joint state using forward kinematics after inverse kinematics
            self.tActual = self.robot.model.fkine(self.qEnd).T;  % Get the actual transformation matrix
            self.desiredPose = t2(1:3, 4);  % Extract the desired position (x, y, z) from transformation matrix
            self.actualPose = self.tActual(1:3, 4);  % Extract the actual position from the forward kinematics result

            % Compute the position error between the desired and actual positions
            self.positionError = norm(self.desiredPose - self.actualPose);  % Calculate Euclidean distance

            % Check if the error is within the tolerance (5mm)
            if self.positionError <= self.tolerance
                disp('Pose satisfied within +- 5mm.');  % Success message
            else
                disp('Pose does not meet the +-5mm tolerance.');  % Error message if tolerance is not met
            end

            % Display the desired and actual positions for debugging
            disp('Desired pose:');
            disp(self.desiredPose);

            disp('Actual pose:');
            disp(self.actualPose);

            disp('Position error:');
            disp(self.positionError);

            % Generate the trajectory using LSPB (Linear Segment with Parabolic Blend) for smooth motion
            s = lspb(0, 1, self.steps);  % Time scaling for the trajectory
            path2 = nan(self.steps, 7);  % Preallocate the path array

            % Interpolate joint angles between the starting and ending configurations
            for j = 1:self.steps
                path2(j,:) = (1-s(j)) * self.qStart + s(j) * self.qEnd;  % Interpolate joint configurations
            end

            % Animate the robot and gripper along the trajectory
            for j = 1:self.steps
                self.robot.model.animate(path2(j, :));  % Animate the robot at each step
                Tr = self.robot.model.fkine(path2(j,:)).T * troty(-pi/2);  % Get the transformation matrix and rotate the gripper
                self.gripper.robot.delay = 0;  % No delay for gripper animation
                self.gripper.animateGripper(Tr);  % Animate the gripper to follow the end-effector
                axis equal;  % Keep axis scaling equal for proper visualization
                drawnow();  % Update the figure window for real-time animation
                pause(0.01);  % Pause for a short duration to control animation speed

                % Try to delete any previous text handle if it exists
                try delete(self.text_h); end %#ok<TRYNC>

                % Compute and display the final transformation at the last step
                Tr2 = self.robot.model.fkine(path2(size(self.steps,1),:)).T;  % Get the final transformation matrix
                try delete(Tr2); end %#ok<TRYNC>  % Try to delete Tr2 if it exists

                % Create a message showing the final pose information
                message = sprintf([num2str(round(Tr2(1,:),2,'significant')),'\n' ...
                    num2str(round(Tr2(2,:),2,'significant')),'\n' ...
                    num2str(round(Tr2(3,:),2,'significant'))]);

                % Display the final pose as text in the plot
                self.text_h = text(0, 0, 3, message, 'FontSize', 10, 'Color', [.6 .2 .6]);  % Purple text
                drawnow();  % Update the figure window to show the text
            end

            % Update the starting configuration for the next move
            self.qStart = self.qEnd;

        end




        function AboveDropoffZone(self)
            % Move to the dropoff zone above the target
            disp("STATUS: MOVING TO DROP OFF ZONE");  % Display the current action
            fprintf('\n');  % New line for cleaner output

            % Generate the transformation to move above the dropoff zone
            t3 = transl([-0.75, 0.5, 0.5]) * rpy2tr(180,0,0,'deg');
            self.qEnd = self.robot.model.ikcon(t3);  % Calculate inverse kinematics to find joint configuration

            % Compute the actual joint state using forward kinematics after inverse kinematics
            self.tActual = self.robot.model.fkine(self.qEnd).T;  % Get the actual transformation matrix
            self.desiredPose = t3(1:3, 4);  % Extract the desired position (x, y, z) from transformation matrix
            self.actualPose = self.tActual(1:3, 4);  % Extract the actual position from the forward kinematics result

            % Compute the position error between the desired and actual positions
            self.positionError = norm(self.desiredPose - self.actualPose);  % Calculate Euclidean distance

            % Check if the error is within the tolerance (5mm)
            if self.positionError <= self.tolerance
                disp('Pose satisfied within +- 5mm.');  % Success message
            else
                disp('Pose does not meet the +-5mm tolerance.');  % Error message if tolerance is not met
            end

            % Display the desired and actual positions for debugging
            disp('Desired pose:');
            disp(self.desiredPose);

            disp('Actual pose:');
            disp(self.actualPose);

            disp('Position error:');
            disp(self.positionError);

            % Generate the trajectory using LSPB for smooth motion
            s = lspb(0, 1, self.steps);  % Time scaling for the trajectory
            path3 = nan(self.steps, 7);  % Preallocate the path array

            % Interpolate joint angles between the starting and ending configurations
            for j = 1:self.steps
                path3(j,:) = (1-s(j)) * self.qStart + s(j) * self.qEnd;  % Interpolate joint configurations
            end

            % Animate the robot and gripper along the trajectory
            for j = 1:self.steps
                self.robot.model.animate(path3(j, :));  % Animate the robot at each step
                Tr = self.robot.model.fkine(path3(j,:)).T * troty(-pi/2);  % Get the transformation matrix and rotate the gripper
                self.gripper.robot.delay = 0;  % No delay for gripper animation
                self.gripper.animateGripper(Tr);  % Animate the gripper to follow the end-effector
                axis equal;  % Keep axis scaling equal for proper visualization
                drawnow();  % Update the figure window for real-time animation
                pause(0.01);  % Pause for a short duration to control animation speed

                % Try to delete any previous text handle if it exists
                try delete(self.text_h); end %#ok<TRYNC>

                % Compute and display the final transformation at the last step
                Tr3 = self.robot.model.fkine(path3(size(self.steps,1),:)).T;  % Get the final transformation matrix
                try delete(Tr3); end %#ok<TRYNC>  % Try to delete Tr3 if it exists

                % Create a message showing the final pose information
                message = sprintf([num2str(round(Tr3(1,:),2,'significant')),'\n' ...
                    num2str(round(Tr3(2,:),2,'significant')),'\n' ...
                    num2str(round(Tr3(3,:),2,'significant'))]);

                % Display the final pose as text in the plot
                self.text_h = text(0, 0, 3, message, 'FontSize', 10, 'Color', [.6 .2 .6]);  % Purple text
                drawnow();  % Update the figure window to show the text
            end

            % Update the starting configuration for the next move
            self.qStart = self.qEnd;

        end




        function ReleaseBrick(self, brickIndex)
            % Release the brick at the dropoff zone using brickEnd from the Bricks class
            disp("STATUS: PLACING BRICK AT DROP OFF ZONE");  % Display the status message
            fprintf('\n');  % New line for clean output formatting

            % Calculate the transformation matrix for the dropoff position of the brick
            t4 = transl(self.bricks.brickEnd(brickIndex,:)) * rpy2tr(180,0,0,'deg');
            self.qEnd = self.robot.model.ikcon(t4);  % Compute the joint angles using inverse kinematics

            % Compute the actual joint state using forward kinematics after inverse kinematics
            self.tActual = self.robot.model.fkine(self.qEnd).T;  % Get the actual transformation matrix
            self.desiredPose = t4(1:3, 4);  % Extract the desired position (x, y, z)
            self.actualPose = self.tActual(1:3, 4);  % Extract the actual position

            % Compute the position error between the desired and actual positions
            self.positionError = norm(self.desiredPose - self.actualPose);  % Euclidean distance

            % Check if the position error is within the tolerance (5mm)
            if self.positionError <= self.tolerance
                disp('Pose satisfied within +- 5mm.');
            else
                disp('Pose does not meet the +-5mm tolerance.');
            end

            % Display the desired and actual positions for debugging purposes
            disp('Desired pose:');
            disp(self.desiredPose);

            disp('Actual pose:');
            disp(self.actualPose);

            disp('Position error:');
            disp(self.positionError);

            % Generate a smooth trajectory using LSPB (Linear Segment with Parabolic Blend)
            s = lspb(0, 1, self.steps);  % Time scaling for smooth motion
            path4 = nan(self.steps, 7);  % Preallocate memory for joint trajectory

            % Interpolate between the start and end joint configurations
            for j = 1:self.steps
                path4(j,:) = (1-s(j)) * self.qStart + s(j) * self.qEnd;  % Linear interpolation
            end

            % Animate the robot and the gripper as it follows the trajectory
            for j = 1:self.steps
                self.robot.model.animate(path4(j, :));  % Animate the robot joint states
                Tr = self.robot.model.fkine(path4(j,:)).T * troty(-pi/2);  % Get the transformation matrix for the gripper
                self.gripper.robot.delay = 0;  % Set the delay for gripper animation
                self.gripper.animateGripper(Tr);  % Animate the gripper following the end-effector
                axis equal;  % Keep axis scaling uniform
                drawnow();  % Update the plot

                % Add a small pause to control the animation speed
                pause(0.01);

                % Try to delete the previous text handle to avoid overlap
                try delete(self.text_h); end %#ok<TRYNC>

                % Compute the final transformation at the last step of the trajectory
                Tr4 = self.robot.model.fkine(path4(size(self.steps,1),:)).T;
                try delete(Tr4); end %#ok<TRYNC>  % Try deleting any residual transformations

                % Create and display the final pose information as a message
                message = sprintf([num2str(round(Tr4(1,:),2,'significant')),'\n' ...
                    num2str(round(Tr4(2,:),2,'significant')),'\n' ...
                    num2str(round(Tr4(3,:),2,'significant'))]);
                self.text_h = text(0, 0, 3, message, 'FontSize', 10, 'Color', [.6 .2 .6]);  % Display message with purple text
                drawnow();  % Update the plot
            end

            % Update the starting joint configuration for the next move
            self.qStart = self.qEnd;
        end



        function ReturnHome(self)
            % Return the robot to the home position after finishing the task
            disp("STATUS: RETURNING HOME");  % Display the status message
            fprintf('\n');  % New line for clean output formatting

            % Calculate the transformation matrix for the home position
            t5 = transl([-0.75, 0.5, 0.5]) * rpy2tr(180,0,0,'deg');
            self.qEnd = self.robot.model.ikcon(t5);  % Compute the joint angles using inverse kinematics

            % Compute the actual joint state using forward kinematics
            self.tActual = self.robot.model.fkine(self.qEnd).T;  % Get the actual transformation matrix
            self.desiredPose = t5(1:3, 4);  % Extract the desired position (x, y, z)
            self.actualPose = self.tActual(1:3, 4);  % Extract the actual position

            % Compute the position error between the desired and actual positions
            self.positionError = norm(self.desiredPose - self.actualPose);  % Euclidean distance

            % Check if the position error is within the tolerance (5mm)
            if self.positionError <= self.tolerance
                disp('Pose satisfied within +- 5mm.');
            else
                disp('Pose does not meet the +-5mm tolerance.');
            end

            % Display the desired and actual positions for debugging purposes
            disp('Desired pose:');
            disp(self.desiredPose);

            disp('Actual pose:');
            disp(self.actualPose);

            disp('Position error:');
            disp(self.positionError);

            % Generate a smooth trajectory using LSPB for smooth motion
            s = lspb(0, 1, self.steps);  % Time scaling for smooth motion
            path5 = nan(self.steps, 7);  % Preallocate memory for the joint trajectory

            % Interpolate between the start and end joint configurations
            for j = 1:self.steps
                path5(j,:) = (1-s(j)) * self.qStart + s(j) * self.qEnd;  % Linear interpolation
            end

            % Animate the robot and gripper along the return home trajectory
            for j = 1:self.steps
                self.robot.model.animate(path5(j, :));  % Animate the robot joint states
                Tr = self.robot.model.fkine(path5(j,:)).T * troty(-pi/2);  % Get the transformation matrix for the gripper
                self.gripper.robot.delay = 0;  % Set the delay for the gripper
                self.gripper.animateGripper(Tr);  % Animate the gripper following the end-effector
                axis equal;  % Keep axis scaling uniform
                drawnow();  % Update the plot

                % Add a small pause to control the animation speed
                pause(0.01);

                % Try to delete the previous text handle to avoid overlap
                try delete(self.text_h); end %#ok<TRYNC>

                % Compute the final transformation at the last step
                Tr5 = self.robot.model.fkine(path5(size(self.steps,1),:)).T;
                try delete(Tr5); end %#ok<TRYNC>  % Try deleting any residual transformations

                % Create and display the final pose information as a message
                message = sprintf([num2str(round(Tr5(1,:),2,'significant')),'\n' ...
                    num2str(round(Tr5(2,:),2,'significant')),'\n' ...
                    num2str(round(Tr5(3,:),2,'significant'))]);
                self.text_h = text(0, 0, 3, message, 'FontSize', 10, 'Color', [.6 .2 .6]);  % Display message with purple text
                drawnow();  % Update the plot
            end

            % Update the starting joint configuration for the next move
            self.qStart = self.qEnd;
        end

    end
end