% Eye tracking light field test

% Housekeeping
if exist('vid'), stop(vid), end, clear; tic;
warning off Images:initSize:adjustingMag %Suppress image size warning
addpath C:\Users\Admin\Desktop\D'igital Aperture Code\Eye Tracking'
addpath C:\Users\Admin\Desktop\D'igital Aperture Code\Eye Tracking\bin'

% Define light field size and location
lightFieldSize = [10, 10];
lightFieldPath = 'C:\Users\Admin\Desktop\Digital Aperture Code\MatchboxBroncoCabin\';

% Load images into a cell array
for ii = 1:lightFieldSize(2)
    for jj = 1:lightFieldSize(1)
        disp(sprintf('%sLightField%i_%i.jpg', lightFieldPath, ii, jj));
        images{jj,ii} = imread(sprintf('%sLightField%i_%i.jpg', ...
            lightFieldPath, ii, jj), 'JPEG');
    end
end

% Open figure to display current perspective, and waitbar
figureHandle = figure; imshow(images{round(lightFieldSize(1)/2), ...
    round(lightFieldSize(2)/2)}); maximize(figureHandle);
msgBoxHandle = msgbox('Click Here When You Are Done');

% Start eye tracking
vid=videoinput('winvideo',1,getResolution());
triggerconfig(vid,'manual');
set(vid,'ReturnedColorSpace','rgb' );
start(vid);

% Define eye movement bounding box
boundingBoxBorder = [0.20, 0.20];

% Run perspective change while message box is open
cd Eye' Tracking'\ %Eye tracking must be run from its folder...LAME
while ishandle(msgBoxHandle)
    % Look for eyes, update perspective if found
    snapshot = getsnapshot(vid);
    [T] = getPoints(snapshot);
    if T~=-1
        % Calculate perspective
        webcamSize = size(snapshot); webcamSize = webcamSize(1:2);
        nominalPosition = [(T(8)+T(10))/2, (T(7)+T(9))/2];
        perspective = (nominalPosition - boundingBoxBorder.*webcamSize)./ ...
            (webcamSize.*boundingBoxBorder*2)
        perspective = min(max(perspective,[0,0]),[1,1]);
        perspective(2) = 1 - perspective(2);
        % Update display with correct image
        perspectiveIndex = round(1+perspective.*(lightFieldSize-1))
        figure(figureHandle);
        imshow(images{perspectiveIndex(1),perspectiveIndex(2)}); drawnow;
    end
end
cd ..

% Clean up before exiting
stop(vid)
