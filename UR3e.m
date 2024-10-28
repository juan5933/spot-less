classdef UR3e < RobotBaseClass
    %% UR3e Universal Robot 3kg payload robot model
    %
    % WARNING: This model has been created by UTS students in the subject
    % 41013. No guarentee is made about the accuracy or correctness of the
    % of the DH parameters of the accompanying ply files. Do not assume
    % that this matches the real robot!

    properties(Access = public)   
        plyFileNameStem = 'UR3e';
    end
    
    methods
%% Constructor
        function self = UR3e(baseTr,useTool,toolFilename)
            if nargin < 3
                if nargin == 2
                    error('If you set useTool you must pass in the toolFilename as well');
                elseif nargin == 0 % Nothing passed
                    baseTr = transl(-0.5,1.1,1.3); 
                end             
            else % All passed in 
                self.useTool = useTool;
                toolTrData = load([toolFilename,'.mat']);
                self.toolTr = toolTrData.tool;
                self.toolFilename = [toolFilename,'.ply'];
            end
          
            self.CreateModel();

            
            % % New values for the ellipsoid (guessed these, need proper model to work out correctly)
            % centerPoint = [0,0,0];
            % radii = [0.2,0.05,0.05];
            % [X,Y,Z] = ellipsoid( centerPoint(1), centerPoint(2), centerPoint(3), radii(1), radii(2), radii(3) );
            % for i = 1:7
            %     self.model.points{i} = [X(:),Y(:),Z(:)];
            %     warning off
            %     self.model.faces{i} = delaunay(self.model.points{i});
            %     warning on;
            % end

            % Create ellipsoid for collision detection

            % Define the center points and radii for each link
            % Example values, customize as needed for each link
            centerPoints = [
                0, 0, 0;  % Link 1
                0, 0, 0;  % Link 2
                0.12, 0, 0.12;  % Link 3
                0.12, 0, 0;  % Link 4
                0, 0, 0;  % Link 5
                0, 0, 0;  % Link 6
                0, 0, 0   % Link 7
                ];

            radiiValues = [
                0.08, 0.08, 0.15;  % Link 1
                0.07, 0.07, 0.08; % Link 2
                0.19, 0.09, 0.09;  % Link 3
                0.18, 0.08, 0.08; % Link 4
                0.05, 0.05 0.05;  % Link 5
                0.06, 0.06, 0.07;   % Link 6
                0.05, 0.05, 0.04   % Link 7
                ];

            % Generate an ellipsoid for each link with specified parameters
            for i = 1:7
                centerPoint = centerPoints(i, :);
                radii = radiiValues(i, :);

                % Generate ellipsoid with custom parameters for this link
                [X, Y, Z] = ellipsoid(centerPoint(1), centerPoint(2), centerPoint(3), radii(1), radii(2), radii(3));

                % Store points and faces for the model
                self.model.points{i} = [X(:), Y(:), Z(:)];

                % Suppress warnings for Delaunay triangulation and create faces
                warning off
                self.model.faces{i} = delaunay(self.model.points{i});
                warning on
            end



            % axis equal
            axis([-0.1 0.1 -0.1 0.1 -0.1 0.1]); % Adjust based on your ellipsoid dimensions

            self.model.plot3d([0,0,0,0,0,0]);
            camlight
            hold on

			self.model.base = self.model.base.T * baseTr;
            self.model.tool = self.toolTr;
			warning('The DH parameters are correct. But as of July 2023 the ply files for this UR3e model are definitely incorrect, since we are using the UR3 ply files renamed as UR3e. Once replaced remove this warning.')  
            self.PlotAndColourRobot();
            

            drawnow
        end

%% CreateModel
        function CreateModel(self)
            link(1) = Link('d',0.15185,'a',0,'alpha',pi/2,'qlim',deg2rad([-360 360]), 'offset',0);
            link(2) = Link('d',0,'a',-0.24355,'alpha',0,'qlim', deg2rad([-360 360]), 'offset',0);
            link(3) = Link('d',0,'a',-0.2132,'alpha',0,'qlim', deg2rad([-360 360]), 'offset', 0);
            link(4) = Link('d',0.13105,'a',0,'alpha',pi/2,'qlim',deg2rad([-360 360]),'offset', 0);
            link(5) = Link('d',0.08535,'a',0,'alpha',-pi/2,'qlim',deg2rad([-360,360]), 'offset',0);
            link(6) = Link('d',	0.0921,'a',0,'alpha',0,'qlim',deg2rad([-360,360]), 'offset', 0);
             
            self.model = SerialLink(link,'name',self.name);
        end      
    end
end
