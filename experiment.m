function [Test, Train, After] = MotorAdaptation_v1(n_trials,input_device,test_subject)
%% 
%[Test, Train, After] = MotorAdaptation_v1(n_trials,input_device)
% Example: n_trials = [10 10 10]; - trials for each phase of experiment
% input_device = 'Mouse' or 'Joystick' or 'Gamepad'
% This script generates a game using Psychtoolbox to study visuomotor 
% adaptation in humans. The subjects have the primary goal of reaching with 
% the cursor a red target. The protocol starts with a train phase where the
% target has a randomly attributed position per trial in one of eight
% possible positions. The protocol passes to a test phase where the goal 
% is the same but the cursor is rotated 45?. The program ends with a after phase 
% that is the same as the train phase.
%%

% Clear the workspace and the screen
close all;
clear all;
sca
PsychDefaultSetup(2);


switch input_device% 0: Mouse; 1: Joystick; 2: Gamepad
    case 'Mouse'
        USE_DEVICE = 0;
    case 'Joystick'
        USE_DEVICE = 1;
    case 'Gamepad'
        USE_DEVICE = 2;
    otherwise
        error('That input device is not supported. Asshole -.-')
end
% assert((USE_DEVICE>-1&&USE_DEVICE<3), 'Use correct input device index! 0: Mouse; 1: Joystick; 2: Gamepad');
if ispc % 0: Windows; 1: MacOS
    USE_OS =0;
elseif ismac
    USE_OS=1;
else
    error('Linux is not supported. Asshole -.-')
end  
% assert((USE_DEVICE>-1&&USE_DEVICE<2), 'Use correct OS index! 0: Windows; 1: MacOS');

jmax=2^16;

% Number of trial per phase
NumberTrialsProtocol = n_trials(1);
NumberTrialsTrain = n_trials(2);
NumberTrialsAfter = n_trials(3);

% Initialize structures to store the data
Train.TrialDataXYTrain = cell(NumberTrialsTrain,1);
Train.ShotDataXYTrain = cell(NumberTrialsTrain,1);
Train.AngleShotTrain = cell(NumberTrialsTrain,1);
Train.AngleTargetTrain = cell(NumberTrialsTrain,1);
Train.ForceFieldTrain = cell(NumberTrialsTrain,1);
Train.TargetDataXYTrain = cell(NumberTrialsTrain,1);

Test.TrialDataXYTest = cell(NumberTrialsTrain,1);
Test.ShotDataXYTest = cell(NumberTrialsTrain,1);
Test.AngleShotTest = cell(NumberTrialsTrain,1);
Test.AngleTargetTest = cell(NumberTrialsTrain,1);
Test.AngleCueTest = cell(NumberTrialsTrain,1);
Test.ForceFieldTest = cell(NumberTrialsTrain,1);
Test.TargetDataXYTest = cell(NumberTrialsTrain,1);
Test.CueDataXYTest = cell(NumberTrialsTrain,1);

After.TrialDataXYAfter = cell(NumberTrialsAfter,1);
After.ShotDataXYAfter = cell(NumberTrialsAfter,1);
After.AngleShotAfter = cell(NumberTrialsAfter,1);
After.AngleTargetAfter = cell(NumberTrialsAfter,1);
After.ForceFieldAfter = cell(NumberTrialsAfter,1);
After.TargetDataXYAfter = cell(NumberTrialsAfter,1);

% Get the window handle and screen properties
screens = Screen('Screens');
screenNumber = max(screens);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, white);
[screenXpixels, screenYpixels] = Screen('WindowSize', window);
[xCenter, yCenter] = RectCenter(windowRect);
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

% Run the program in high priority
topPriorityLevel = MaxPriority(window);

% Define properties of the baseic objects to draw
dotColor = 0.*[1 1 1]; % black dot as cursor
dotColor2 = 1.*[1 0 0]; % red dot as target
rectColor = [0 0 0];
baseRect = [0 0 0.45 * screenYpixels 0.45 * screenYpixels];
baseRect2 = [0 0 15 15];
maxDiameter = max(baseRect) * 1.01;
centeredRect = CenterRectOnPointd(baseRect, xCenter, yCenter);

dotSizePix = 20;
dotPositionMatrix = [];
dotSizes = [];
dotColorsMatrix = [];
dotCenter = [];

% Initialize target position
t1Xpos = screenXpixels;
t1Ypos = screenYpixels;

% Angular positions to draw
drawingPositions = 0:pi/8:2*pi;
% Possible target angular positions
possiblePositions = 0:pi/4:2*pi;

% Create the matrix of dots to draw equidistant from 0 and at the defined
% angles
dotPositionMatrixTicks = [];
dotColorsMatrixTicks = [];
dotSizesTicks = [];
dotCenterTicks = [];
for i = 1 : length(drawingPositions)
    dotPositionMatrixTicks = horzcat(dotPositionMatrixTicks, [(0.45 * screenYpixels * sin(drawingPositions(i)) + xCenter); (-0.45 * screenYpixels * cos(drawingPositions(i)) + yCenter)]);
    dotColorsMatrixTicks = horzcat(dotColorsMatrixTicks, [0.8; 0.8; 0.8]);
    dotSizesTicks = vertcat(dotSizesTicks, 15);
    dotCenterTicks = [0 0];
end

% Define the roation for test phase
tt = pi/4; % rotation value
R = [cos(tt), -sin(tt); sin(tt), cos(tt)]; % rotation matrix

% Reset the mouse to tha center and hide cursor
HideCursor()
if USE_DEVICE==0
    SetMouse(xCenter, yCenter, window);
else
    jxm=jmax/2; jym=jmax/2;    
end

% Auxiliary variables to build the protocol
% Within each phase the protocol can be in a trial or intertrial (State)
State = 0;
nTrialt = 0;
nTrialp = 0;
nTriala = 0;
TrialDXY = [];
ttr = possiblePositions(randi(9,1));

% The protocol if just a sequence of menus
menu = 0;

% If ESC is pressed exit the game
escapeKey = KbName('ESCAPE');
exitDemo = false;
while ~exitDemo
    [keyIsDown,secs, keyCode] = KbCheck;
    if menu == 0
        % Menu 0 is just the introduction text
        while ~KbCheck
            [keyIsDown,secs, keyCode] = KbCheck;
            line1 = 'Hello Subject';
            line2 = '\n\n\n We will now begin the training phase ';
            line3 = '\n\n\n Press any key to continue';
            Screen('TextSize', window, 25 );
            DrawFormattedText(window, [line1 line2 line3],...
                'center', screenYpixels * 0.25, black);
            Screen('Flip', window);
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
        end
        while KbCheck
            [keyIsDown, secs, keyCode] = KbCheck;
        end
        [keyIsDown,secs, keyCode] = KbCheck;
        while ~KbCheck
            [keyIsDown,secs, keyCode] = KbCheck;
            line1 = '>> This phase has several trials and requires you to ';
            line2 = '\n\n "slice straight" through a target (red dot)';
            line6 = '\n\n\n >> The black dot represents your position in the arena';
            line8 = '\n\n\n >> A green dot will appear giving you feedback on your performance';
            line5 = '\n\n\n >> Every trial starts with the black dot in center of the screen';
            line7 = '\n\n\n >> The movement should be balistic, performance includes speed and accuracy';
            line3 = '\n\n\n >> After the blue dot appears on the center press the ';
            line4 = '\n\n mouse left key to reset the cursor and start a new trial';
            line9 = '\n\n\n Press any key to continue';
            Screen('TextSize', window, 20 );
            DrawFormattedText(window, [line1 line2 line3 line4 line5 line6 line7 line8 line9],...
                'center', screenYpixels * 0.25, black);
            Screen('Flip', window);
            
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
        end
        
        % Reset the dots positions
        t1Xpos = screenXpixels;
        t1Ypos = screenYpixels;
        dotPositionMatrix = [];
        
        % After introduction pass to menu 1
        menu = 1;
    elseif menu == 1
        % Menu 1 is the training phase
        % Priority level of the process is maximum
        Priority(topPriorityLevel);
        % Train phase runs until the number of trials for train is complete
        % or ESC is pressed
        while nTrialt < NumberTrialsTrain+1
            [keyIsDown,secs, keyCode] = KbCheck;
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
            % Get the mouse position
            if USE_DEVICE==0
                [xm, ym, buttons] = GetMouse(window);
            elseif USE_DEVICE==1
                [jxm jym jzm buttons]= WinJoystickMex(0);
                xm=(jxm/jmax) * screenXpixels;
                ym = jym/jmax * screenYpixels;
            else
                
            end
            % Get mouse distance from center
            rr = sqrt((xm-xCenter)^2 + (ym-yCenter)^2);
            % If it's a trial
            if State == 1
                % Draw a blue dot in the center
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                % Save cursor position per frame
                TrialDXY = vertcat(TrialDXY, [(xm-xCenter) (-ym+yCenter)]);
                dotColor = [0 0 0];
                r = [(xm-xCenter); (ym-yCenter)];
                % Target position
                t1Xpos = 0.45 * screenYpixels * sin(ttr) + xCenter;
                t1Ypos = -0.45 * screenYpixels * cos(ttr) + yCenter;
                % Draw the dot that represents the cursor
                Screen('DrawDots', window, [r(1)+xCenter r(2)+yCenter], dotSizePix, dotColor, [], 2);
                % If cursor is out of bounds
                if rr > 0.45 * screenYpixels
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('Flip', window);
                    % Compute ending angle
                    theta = atan(r(1)/r(2));
                    xxx = 0.45 * screenYpixels * sin(theta+pi);
                    yyy = 0.45 * screenYpixels * cos(theta+pi);
                    if r(2) < 0
                        t = theta+pi;
                        xxx = 0.45 * screenYpixels * sin(t);
                        yyy = 0.45 * screenYpixels * cos(t);
                    else
                        t = theta;
                        xxx = 0.45 * screenYpixels * sin(t);
                        yyy = 0.45 * screenYpixels * cos(t);
                    end
                    % Performance green dot properties
                    dotPositionMatrix = [xxx+xCenter; yyy+yCenter];
                    dotColorsMatrix = [0; 1; 0];
                    dotSizes = 10;
                    dotCenter = [0 0];
                    % Go to inter trial
                    State = 0;
                    % Increment trial number
                    nTrialt = nTrialt + 1;
                    % Store the data
                    Train.TrialDataXYTrain{nTrialt} = TrialDXY;
                    Train.ShotDataXYTrain{nTrialt} = [xxx; yyy];
                    Train.TargetDataXYTrain{nTrialt} = [t1Xpos-xCenter; t1Ypos-yCenter];
                    Train.AngleShotTrain{nTrialt} = t;
                    Train.AngleTargetTrain{nTrialt} = ttr;
                    Train.ForceFieldTrain{nTrialt} = 0;
                    SetMouse(r(1) + xCenter, r(2) + yCenter, window);
                    % Draw the green dot, target and positions
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
                    Screen('Flip', window);
                    % Force some waiting time before next trial
                    WaitSecs(0.5);
                end
            % If intertrial
            else
                % Draw a blue dot
                % Don't draw the cursor representative
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                dotColor = [1 0 1];
                r = [(xm-xCenter); (ym-yCenter)];
                % Force cursor to go to the center
                SetMouse(xCenter, yCenter, window);
                % Press in the center to start next trial 
                if buttons(1) == 1 && rr <10
                    State = 1;
                    % Randomised next target position
                    ttr = possiblePositions(randi(9,1));
                    dotPositionMatrix = [];
                end
            end
            % Draw the target and position dots
            Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
            Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
            if ~isempty(dotPositionMatrix)
                Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
            end
            Screen('Flip', window);
        end
        % Reset positions
        t1Xpos = screenXpixels;
        t1Ypos = screenYpixels;
        CueXpos = screenXpixels;
        CueYpos = screenXpixels;
        dotPositionMatrix = [];
        % Go to menu 2
        menu = 2;
        % Go back to low priority
        Priority(0);
    elseif menu == 2
        % Menu 2 is just an introduction to the test phase
        while ~KbCheck
            [keyIsDown,secs, keyCode] = KbCheck;
            line1 = '>> You will now start the test phase';
            line2 = '\n\n\n >> All the rules previously described still apply';
            line4 = '\n\n\n >> In addition, a rotation was applied to the cursor.';
%             line5 = '\n\n >> Hint: aim for the dark gray position';
            line7 = '\n\n\n Press any key to continue';
            Screen('TextSize', window, 25 );
            DrawFormattedText(window, [line1 line2 line4 line7],...
                'center', screenYpixels * 0.25, black);
            Screen('Flip', window);
            
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
        end
        % Go to menu 3
        menu = 3;
    elseif menu == 3
        % Menu 3 is the test phase
        % Priority level of the process is maximum
        Priority(topPriorityLevel);
        % Test phase runs until the number of trials for test is complete
        % or ESC is pressed
        while nTrialp < NumberTrialsProtocol+1
            [keyIsDown,secs, keyCode] = KbCheck;
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
            % Get the mouse position
            if ~joystick_in
                [xm, ym, buttons] = GetMouse(window);
            else              
                [jxm jym jzm buttons]= WinJoystickMex(0);
                xm=(jxm/jmax) * screenXpixels;
                ym = jym/jmax * screenYpixels;
            end

            % Get mouse distance from center
            rr = sqrt((xm-xCenter)^2 + (ym-yCenter)^2);
            % If it's a trial
            if State == 1
                % Draw a blue dot in the center
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                % Save cursor position per frame
                TrialDXY = vertcat(TrialDXY, [(xm-xCenter) (-ym+yCenter)]);
                dotColor = [0 0 0];
                % Target position
                t1Xpos = 0.45 * screenYpixels * sin(ttr) + xCenter;
                t1Ypos = -0.45 * screenYpixels * cos(ttr) + yCenter;
                r = R*[(xm-xCenter); (ym-yCenter)];
                % Draw the dot that represents the cursor
                Screen('DrawDots', window, [r(1)+xCenter r(2)+yCenter], dotSizePix, dotColor, [], 2);
                % If cursor is out of bounds
                if rr > 0.45 * screenYpixels
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('Flip', window);
                    % Compute ending angle
                    theta = atan(r(1)/r(2));
                    if r(2) < 0
                        t = theta+pi;
                    else
                        t = theta;
                    end
                    xxx = 0.45 * screenYpixels * sin(t);
                    yyy = 0.45 * screenYpixels * cos(t);
                    % Performance green dot properties
                    dotPositionMatrix = [xxx+xCenter; yyy+yCenter];
                    dotColorsMatrix = [0; 1; 0];
                    dotSizes = 10;
                    dotCenter = [0 0];
                    % Go to inter trial
                    State = 0;
                    % Increment trial number
                    nTrialp = nTrialp + 1;
                    % Store the data
                    Test.AngleCueTest{nTrialp} = 0;
                    Test.AngleShotTest{nTrialp} = t;
                    Test.AngleTargetTest{nTrialp} = ttr;
                    Test.CueDataXYTest{nTrialp} = [CueXpos; CueYpos];
                    Test.ForceFieldTes{nTrialp} = pi/4;
                    Test.TrialDataXYTest{nTrialp} = TrialDXY;
                    Test.ShotDataXYTest{nTrialp} = [xxx; yyy];
                    Test.TargetDataXYTest = [t1Xpos; t1Ypos];
                    SetMouse(r(1) + xCenter, r(2) + yCenter, window);
                    % Draw the green dot, target and positions
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
                    Screen('Flip', window);
                    % Force some waiting time before next trial
                    WaitSecs(0.5);
                end
            % If intertrial
            else
                % Draw a blue dot
                % Don't draw the cursor representative
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                dotColor = [1 0 1];
                r = [(xm-xCenter); (ym-yCenter)];
                % Force cursor to go to the center
                SetMouse(xCenter, yCenter, window);
                % Press in the center to start next trial
                if buttons(1) == 1 && rr <10
                    State = 1;
                    % Randomised next target position
                    ttr = possiblePositions(randi(9,1));
                    dotPositionMatrix = [];
                end
            end
            % Draw the target and position dots
            Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
            Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
            Screen('FrameOval', window, [0 0 0], CenterRectOnPointd(baseRect2, CueXpos, CueYpos), 2, 2);
            if ~isempty(dotPositionMatrix)
                Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
            end
            Screen('Flip', window);
        end
        % Reset positions
        t1Xpos = screenXpixels;
        t1Ypos = screenYpixels;
        % Go back to low priority
        Priority(0);
        % Go to menu 4
        menu = 4;
    elseif menu == 4
        % Menu 4 is just an introduction to the after phase
        while ~KbCheck
            [keyIsDown,secs, keyCode] = KbCheck;
            line1 = 'Great Job!';
            line2 = '\n\n You are now entering the last part of the test phase';
            line3 = '\n\n Press any key to continue';
            Screen('TextSize', window, 20 );
            DrawFormattedText(window, [line1 line2 line3],...
                'center', screenYpixels * 0.25, black);
            Screen('Flip', window);
            
            
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
        end
        % Go to menu 5
        menu = 5;
    elseif menu == 5
        % Menu 5 is the after phase
        % Priority level of the process is maximum
        Priority(topPriorityLevel);
        % After phase runs until the number of trials for after is complete
        % or ESC is pressed
        while nTriala < NumberTrialsAfter+1
            [keyIsDown,secs, keyCode] = KbCheck;
            if keyCode(escapeKey)
                exitDemo = true;
                break;
            end
            % Get the mouse position
            if USE_DEVICE==0
                [xm, ym, buttons] = GetMouse(window);
            elseif USE_DEVICE==1
                if USE_OS
                [jxm jym jzm buttons]= WinJoystickMex(0);
                xm=(jxm/jmax) * screenXpixels;
                ym = jym/jmax * screenYpixels;
            else
                jxm = Gamepad('GetAxis', USE_DEVICE, 1);
                jym = Gamepad('GetAxis', USE_DEVICE, 2);
                xm=(jxm/jmax) * screenXpixels;
                ym = jym/jmax * screenYpixels;
                buttons(1) = Gamepad('GetButton', USE_DEVICE, 1);
            end
            % Get mouse distance from center
            rr = sqrt((xm-xCenter)^2 + (ym-yCenter)^2);
            % If it's a trial
            if State == 1
                % Draw a blue dot in the center
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                % Save cursor position per frame
                TrialDXY = vertcat(TrialDXY, [(xm-xCenter) (-ym+yCenter)]);
                dotColor = [0 0 0];
                r = [(xm-xCenter); (ym-yCenter)];
                % Target position
                t1Xpos = 0.45 * screenYpixels * sin(ttr) + xCenter;
                t1Ypos = -0.45 * screenYpixels * cos(ttr) + yCenter;
                % Draw the dot that represents the cursor
                Screen('DrawDots', window, [r(1)+xCenter r(2)+yCenter], dotSizePix, dotColor, [], 2);
                % If cursor is out of bounds
                if rr > 0.45 * screenYpixels
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('Flip', window);
                    % Compute ending angle
                    theta = atan(r(1)/r(2));
                    xxx = 0.45 * screenYpixels * sin(theta+pi);
                    yyy = 0.45 * screenYpixels * cos(theta+pi);
                    if r(2) < 0
                        t = theta+pi;
                        xxx = 0.45 * screenYpixels * sin(t);
                        yyy = 0.45 * screenYpixels * cos(t);
                    else
                        t = theta;
                        xxx = 0.45 * screenYpixels * sin(t);
                        yyy = 0.45 * screenYpixels * cos(t);
                    end
                    % Performance green dot properties
                    dotPositionMatrix = [xxx+xCenter; yyy+yCenter];
                    dotColorsMatrix = [0; 1; 0];
                    dotSizes = 10;
                    dotCenter = [0 0];
                    % Go to inter trial
                    State = 0;
                    % Increment trial number
                    nTriala = nTriala + 1;
                    % Store the data
                    After.TrialDataXYAfter{nTriala} = TrialDXY;
                    After.ShotDataXYAfter{nTriala} = [xxx; yyy];
                    After.TargetDataXYAfter{nTriala} = [t1Xpos-xCenter; t1Ypos-yCenter];
                    After.AngleShotAfter{nTriala} = t;
                    After.AngleTargetAfter{nTriala} = ttr;
                    After.ForceFieldAfter{nTriala} = 0;
                    SetMouse(r(1) + xCenter, r(2) + yCenter, window);
                    % Draw the green dot, target and positions
                    Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
                    Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
                    Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
                    Screen('Flip', window);
                    % Force some waiting time before next trial
                end
            % If intertrial  
            else
                % Draw a blue dot
                % Don't draw the cursor representative
                Screen('DrawDots', window, [xCenter yCenter], 5, [0 0 1], [], 2);
                dotColor = [1 0 1];
                r = [(xm-xCenter); (ym-yCenter)];
                % Force cursor to go to the center
                SetMouse(xCenter, yCenter, window);
                % Press in the center to start next trial
                if buttons(1) == 1 && rr <10
                    State = 1;
                    % Randomised next target position
                    ttr = possiblePositions(randi(9,1));
                    dotPositionMatrix = [];
                end
            end
            % Draw the target and position dots
            Screen('DrawDots', window, dotPositionMatrixTicks, dotSizesTicks, dotColorsMatrixTicks, dotCenterTicks, 2);
            Screen('DrawDots', window, [t1Xpos t1Ypos], dotSizePix, dotColor2, [], 2);
            if ~isempty(dotPositionMatrix)
                Screen('DrawDots', window, dotPositionMatrix, dotSizes, dotColorsMatrix, dotCenter, 2);
            end
            Screen('Flip', window);
        end
        % Reset positions
        t1Xpos = screenXpixels;
        t1Ypos = screenYpixels;
        CueXpos = screenXpixels;
        CueYpos = screenXpixels;
        dotPositionMatrix = [];
        % Go back to low priority
        Priority(0);
        break
    end
end
% Protocol is over, show cursor and save the data structures in one file
ShowCursor()
i = 0;
str = ['C:\Users\Rodrigo\Documents\INDP2015\Motor Week\dummyData' num2str(i) '.mat'];
if exist(str, 'file') == 0
    trr = true;
else
    trr = false;
end
while ~trr
    i = i + 1;
    str = ['C:\Users\Rodrigo\Documents\INDP2015\Motor Week\dummyData' num2str(i) '.mat'];
    if exist(str, 'file') == 0
        trr = true;
    else
        trr = false;
    end
end
save(str, 'Test', 'Train', 'After');
sca;

%% Make a performance plot
figure,
subplot(3,1,1)
diff = mod(pi-cell2mat(Train.AngleShotTrain),2*pi)-cell2mat(Train.AngleTargetTrain);
ind = find(diff>pi);
diff(ind) = diff(ind)-2*pi;
ind = find(diff<-pi);
diff(ind) = diff(ind)+2*pi;
plot(180*(smooth(diff))/pi, 'k')
title('Train')
% axis([1 11 -180 180])

subplot(3,1,2)
diff = mod(pi-cell2mat(Test.AngleShotTest),2*pi)-cell2mat(Test.AngleTargetTest);
ind = find(diff>pi);
diff(ind) = diff(ind)-2*pi;
ind = find(diff<-pi);
diff(ind) = diff(ind)+2*pi;
plot(180*(smooth(diff))/pi, 'k')
% axis([1 11 -180 180])
title('Test')


subplot(3,1,3)
diff = mod(pi-cell2mat(After.AngleShotAfter),2*pi)-cell2mat(After.AngleTargetAfter);
ind = find(diff>pi);
diff(ind) = diff(ind)-2*pi;
ind = find(diff<-pi);
diff(ind) = diff(ind)+2*pi;
plot(180*(smooth(diff))/pi, 'k')
% axis([1 11 -180 180])
title('After')
end