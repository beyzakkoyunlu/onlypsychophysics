function results = BisectionDiscThreshold(subID,sesNum,stimLoc,direction)
% Measures bisection discrimination threshold using 3up-1down staircase
%Input:
%
%   subID = subject Id (numeric) (01,02,...)
%   sesNum = session number, determine session number (1,2,3...)
%   stimLoc = stimulus location (1=210 polar angle, 2= 45 polar angle, 3= 150 polar angle)
%
% Output:
%   csv file = subject id, session number, trial number, direction (1=vertical, 2=horizontal),
%   target offset(in pix), target offset(in arcmin), correct(1=correct, 0=wrong), reaction time,
%   txt file = same with csv, tab seperated file, BIDS compatible


% Make sure the script is running on Psychtoolbox-3:
AssertOpenGL;
Screen('Preference', 'SkipSyncTests', 1);
rng('shuffle','twister')

%set default values for input arguments
if ~exist('subID','var')
    subID=666; %demo subject
end
if ~exist('sesNum','var')
    sesNum = 1;
end
if ~exist('stimLoc','var')
    stimLoc = 1;
end
if ~exist('direction','var')
    direction = 1;
end

%Determine location and file name to save results
location=which('BisectionDiscThreshold.m');
location=erase(location,'BisectionDiscThreshold.m');
direcname=fullfile(location, "Data","sub-"+num2str(subID),"ses-"+num2str(sesNum));
mkdir (direcname);
time = datestr(now,'dd-mmm-yy_HH-MM');
if direction == 1
    file.Raw = strcat('sub-',num2str(subID),'_ses-',num2str(sesNum),'_run-vertical',num2str(stimLoc),'_',time);
elseif direction == 2
    file.Raw = strcat('sub-',num2str(subID),'_ses-',num2str(sesNum),'_run-horizontal',num2str(stimLoc),'_',time);
end
try
    PsychDefaultSetup(2)
    % Removes the blue screen flash and minimize extraneous warnings.
    oldVisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 3);
    oldSupressAllWarnings = Screen('Preference', 'SuppressAllWarnings', 1);
    
    % Open the screen
    screenNumber = max(Screen('Screens'));
    
    %Colors
    color.White = WhiteIndex(screenNumber);
    color.Grey = color.White / 2;
    color.Black = BlackIndex(screenNumber);
    
    %Open screen and determine the center
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, color.Grey);
    [screen.x, screen.y] = RectCenter(windowRect);
    
    %Screen and stimulus parameters for eye-tracking lab
    screen.Wid = 43.5; screen.Len = 33.2; screen.Dist = 95;
    screen.PixSideLen = screen.Wid/screen.x*2;
    stimulus.LineLen = ((2*tand(1/2)* screen.Dist)/screen.PixSideLen);
    stimulus.LineWid = ((2*tand(0.1/2)* screen.Dist)/screen.PixSideLen);
    stimulus.DistBtwLines = stimulus.LineLen;
    stimulus.Ecc=4; stimulus.EccPix=((2*tand(stimulus.Ecc/2)* screen.Dist)/screen.PixSideLen); % length and width of a single pixel in cm
    stimulus.Onset=[];stimulus.Offset=[]; TrialNum=150;
    
    %Variables for staircase
    sc.Selection(1:TrialNum-10/2)=1;
    sc.Selection(end+1:TrialNum-10)=2; sc.Selection(end+1:end+10)=3;
    sc.Selection=Shuffle(sc.Selection);
    sc.Easy.Offset(1)=((2*tand(0.5/2)* screen.Dist)/screen.PixSideLen); % Easy staircase starting point
    sc.Hard.Offset(1)=((2*tand(0.08/2)* screen.Dist)/screen.PixSideLen);% Hard staircase starting point
    sc.Motiv.Offset = Shuffle(repmat([10,15,20],1,4));
    sc.Easy.Response=[]; sc.Hard.Response=[];
    sc.Hard.Decrease=0; sc.Easy.Decrease=0; % how many times the test offset decreased/become harder
    sc.Hard.Increase=0; sc.Easy.Increase=0; % how many times the test offset increased/become easier
    sc.Easy.StepS=3; sc.Hard.StepS=3;% starting values, in pixel
    timing.StimOns=[];   timing.TestDur = 0.3; % Stimulus and feedback presentation
    stimulus.TargetOff=zeros(1,TrialNum); % Stimulus target line offset
    stimulus.PosSign = sign(round(rand(1,TrialNum))-0.5); %left or right
    
    % Response keys
    KbName('UnifyKeyNames');
    key.names = KbName('KeyNames');
    key.Right = 39; key.Left = 37; key.Esc = 27;  key.Space = 32;
    
    %Open csv file for saving data in every trial
    file.Csv = strcat(file.Raw, '.csv');
    file.Csv=fullfile( direcname, file.Csv);
    LogCsv = fopen(file.Csv, 'w+');
    if LogCsv == -1 %if text csv is not open, do not start experiment.
        fprintf('ERROR opening .csv file');
        sca; ShowCursor(win.Ptr);
        return
    end
    
    %Calculate bisection stimulus locations
    bisc.Cen = [screen.x-stimulus.EccPix/2, screen.y+stimulus.EccPix/2*sqrt(3);...      % 7 o'clock
        screen.x+stimulus.EccPix/2*sqrt(2), screen.y-stimulus.EccPix/2*sqrt(2);...              % 1.5 o'clock
        screen.x+stimulus.EccPix/2, screen.y+stimulus.EccPix/2*sqrt(3)];                    % 5 o'clock
    if direction == 1
        for i=1:3
            bisc.Coor(1,i) = bisc.Cen(i,2) - stimulus.LineLen;    % upper Y point
            bisc.Coor(2,i) = bisc.Cen(i,2) + stimulus.LineLen;    % bottom Y point
            bisc.Coor(3,i) = bisc.Cen(i,1) + stimulus.LineLen;    % X coordinate right outer line
            bisc.Coor(4,i) = bisc.Cen(i,1) - stimulus.LineLen;    % X coordinate left outer line
            bisc.Coor(5,i) = bisc.Cen(i,1);                                               % X coordinate middle line
        end
    elseif direction == 2
        for i=1:3
            bisc.Coor(1,i) = bisc.Cen(i,2) - stimulus.LineLen;                 % Y coordinate upper outer line
            bisc.Coor(2,i) = bisc.Cen(i,2) + stimulus.LineLen;                 % Y coordinate bottom outer line
            bisc.Coor(3,i) = bisc.Cen(i,1) - stimulus.LineLen;                      % left X point
            bisc.Coor(4,i) = bisc.Cen(i,1) + stimulus.LineLen;                      % right X point
            bisc.Coor(5,i) = bisc.Cen(i,2);                                                    % Y coordinate middle line
        end
    end
    
    % Flip to clear screen
    Screen('Flip', window);
    % Query the frame duration
    screen.Ifi = Screen('GetFlipInterval', window);
    % Query the maximum priority level
    MaxPriority(window);
    
    %Write instructions to screen
    Screen('TextFont', window, 'Courier'); Screen('TextSize', window, 30);
    DrawFormattedText(window, 'Please fixate on center and indicate \n the replacement on the line by using arrow keys \n If middle line is closer to left outer line, press left arrow,\n If middle line is closer to right outer line, press right arrow \n\n Press space key to start ', 'center',...
        screen.y * 0.35, color.Black);
    Screen('DrawDots', window,[screen.x screen.y],10,  color.Black,[], 2);
    Screen('Flip', window);
    keepLooping=1;
    while keepLooping
        [touch, tpress, keyCode] = KbCheck;
        if touch==1 && keyCode(key.Space)==1
            keepLooping=0;
        end
    end
    vbl=0; timing.Start=GetSecs; %Get start time of the experiment
    screen.WaitFrames=1;
    for k=1:TrialNum
        %Determines stimulus offset according to staircase value
        if sc.Selection(k)==1
            stimulus.TargetOff(k) = stimulus.PosSign(k)*sc.Hard.Offset(end); % calculates where the middle line will be showed
        elseif sc.Selection(k)==2
            stimulus.TargetOff(k) = stimulus.PosSign(k)*sc.Easy.Offset(end); % calculates where the middle line will be showed
        elseif sc.Selection(k)==3
            stimulus.TargetOff(k) = stimulus.PosSign(k)*sc.Motiv.Offset(k==(find(sc.Selection==3)));
        end
        
        %Creates stimulus position
        if direction == 1
            TargetX =  bisc.Coor(5,stimLoc)+ stimulus.TargetOff(nth_trial);
            Screen('DrawLine', window, color.Black, TargetX, bisc.Coor(1,stimLoc), TargetX, bisc.Coor(2,stimLoc), stimulus.LineWid);
            Screen('DrawLine', window, color.Black, bisc.Coor(3,stimLoc), bisc.Coor(1,stimLoc), bisc.Coor(3,stimLoc), bisc.Coor(2,stimLoc),stimulus.LineWid);
            Screen('DrawLine', window, color.Black, bisc.Coor(4,stimLoc), bisc.Coor(1,stimLoc), bisc.Coor(4,stimLoc), bisc.Coor(2,stimLoc),stimulus.LineWid);
        elseif direction == 2
            TargetY =  bisc.Coor(5,stimLoc)+ stimulus.TargetOff(nth_trial);
            Screen('DrawLine', window, color.Black, bisc.Coor(3,stimLoc), TargetY, bisc.Coor(4,stimLoc), TargetY, stimulus.LineWid);
            Screen('DrawLine', window, color.Black, bisc.Coor(3,stimLoc), bisc.Coor(1,stimLoc), bisc.Coor(4,stimLoc), bisc.Coor(1,stimLoc),stimulus.LineWid);
            Screen('DrawLine', window, color.Black, bisc.Coor(3,stimLoc), bisc.Coor(2,stimLoc), bisc.Coor(4,stimLoc), bisc.Coor(2,stimLoc),stimulus.LineWid);
        end
        %Present stimulus
        when = vbl + timing.TestDur+ (screen.WaitFrames - 0.5) * screen.Ifi;
        vbl = Screen('Flip', window, when);
        
        %Define trial info
        stimulus.Onset(k)=GetSecs;
        timing.StimOns(k)=stimulus.Onset(k)-timing.Start;
        
        % Get response and indicate what is correct what is not
        when = vbl + timing.TestDur+ (screen.WaitFrames - 0.5) * screen.Ifi;
        Screen('DrawDots', window,[screen.x screen.y],10,  color.Black,[], 2);
        Screen(window, 'Flip', when);
        timing.startresp=GetSecs;
        keepLooping=1;
        stimulus.Offset(k)=GetSecs;
        while keepLooping
            Screen('DrawDots', window,[screen.x screen.y],10,  [0 0 0],[], 2);
            Screen(window, 'Flip', when);
            timing.StartResp=GetSecs;
            [touch, tpress, keyCode] = KbCheck;
            if (keyCode(key.Left)==1 && isequal(stimulus.PosSign(k), -1)) ||...
                    (keyCode(key.Right)==1 && isequal(stimulus.PosSign(k), 1))  % Correct Response
                correct=1;
                timing.StopResp=GetSecs; keepLooping=0;
                fprintf('\n Correct \n');
                if sc.Selection(k)==1
                    sc.Hard.Response(end+1)=1;
                    if length(sc.Hard.Offset)>2 && isequal(sc.Hard.Offset(end),sc.Hard.Offset(end-1),sc.Hard.Offset(end-2))
                        if sc.Hard.Offset(end)-sc.Hard.StepS >= 1 && sc.Hard.Offset(end)-sc.Hard.StepS <= stimulus.DistBtwLines-2
                            sc.Hard.Offset(end+1)=sc.Hard.Offset(end)-sc.Hard.StepS;
                            sc.Hard.Decrease=sc.Hard.Decrease+1;
                        else
                            sc.Hard.Offset(end+1)=sc.Hard.Offset(end);
                        end
                    else
                        sc.Hard.Offset(end+1)=sc.Hard.Offset(end);
                    end
                elseif sc.Selection(k)==2
                    sc.Easy.Response(end+1)=1;
                    if length(sc.Easy.Offset)>2 && isequal(sc.Easy.Offset(end),sc.Easy.Offset(end-1),sc.Easy.Offset(end-2))
                        if sc.Easy.Offset(end)-sc.Easy.StepS >= 1 && sc.Easy.Offset(end)-sc.Easy.StepS <= stimulus.DistBtwLines-2
                            sc.Easy.Offset(end+1)=sc.Easy.Offset(end)-sc.Easy.StepS;
                            sc.Easy.Decrease=sc.Easy.Decrease+1;
                            
                        else
                            sc.Easy.Offset(end+1)=sc.Easy.Offset(end);
                        end
                    else
                        sc.Easy.Offset(end+1)=sc.Easy.Offset(end);
                    end
                elseif sc.Selection(k)==3
                    sc.Motiv.Response(end+1)=1;
                end
            elseif (keyCode(key.Left)==1 && isequal(stimulus.PosSign(k), 1)) ||...
                    (keyCode(key.Right)==1 && isequal(stimulus.PosSign(k), -1))  % Incorrect Response (1 means right -1 means left)
                correct=0;
                timing.StopResp=GetSecs; keepLooping=0;
                fprintf('\n Wrong \n');
                if sc.Selection(k)==1
                    sc.Hard.Response(end+1)=0;
                    sc.Hard.Increase=sc.Hard.Increase+1;
                    if sc.Hard.Offset(end)+sc.Hard.StepS >= 1 && sc.Hard.Offset(end)+sc.Hard.StepS <= stimulus.DistBtwLines-2
                        sc.Hard.Offset(end+1)=sc.Hard.Offset(end)+sc.Hard.StepS;
                    else
                        sc.Hard.Offset(end+1)=sc.Hard.Offset(end);
                    end
                elseif sc.Selection(k)==2
                    sc.Easy.Response(end+1)=0;
                    sc.Easy.Increase=sc.Easy.Increase+1;
                    if sc.Easy.Offset(end)-sc.Easy.StepS <= stimulus.DistBtwLines-2 && sc.Easy.Offset(end)-sc.Easy.StepS >1
                        sc.Easy.Offset(end+1)=sc.Easy.Offset(end)+sc.Easy.StepS;
                    else
                        sc.Easy.Offset(end+1)=sc.Easy.Offset(end);
                    end
                elseif sc.Selection(k)==3
                    sc.Easy.Response(end+1)=0;
                end
            elseif keyCode(key.Esc)==1
                fprintf('\nEscape key pressed\n')
                sca;
                ShowCursor(window);
                keepLooping=0;
                %return
            end
        end
        if sc.Hard.Decrease>=3 && sc.Hard.Increase>=3
            sc.Hard.StepS=1;
        end
        if sc.Easy.Decrease>=3 && sc.Easy.Increase>=3
            sc.Easy.StepS=1;
        end
        timing.rt(k)=timing.StopResp-timing.startresp;
        stimulus.TargetOffArcMin(k)=(2*180*atan(stimulus.TargetOff(k)*screen.PixSideLen/(2*screen.Dist))/pi)*60;
        results(k,:)=[subID, sesNum, k ,direction,stimulus.TargetOff(k),stimulus.TargetOffArcMin(k), correct, timing.rt(k)];
        dlmwrite(file.Csv,results(k,:),'delimiter',',','-append');
    end
catch
    %If there is an error, this part will run
    save(char(fullfile( direcname,char(strcat('ERROR_', file.Raw, '.mat')))))
    Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
    Screen('Preference', 'SuppressAllWarnings', oldSupressAllWarnings);
    fprintf('You are in trouble my friend. \n');
    psychrethrow(psychlasterror);
    fprintf('This last text never prints.\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   SAVE EXPERIMENT DATA   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
timing.End = GetSecs;
timing.SessionDur = round(timing.End - timing.Start)/60; %minutes
fprintf( '\n\nTotal Session Duration: %.2f min\n', timing.SessionDur);
fclose(LogCsv);
%Save workspace as mat file
save(char(fullfile( direcname, file.Raw)))
%Save values in BIDS format
results=array2table(results);
results.Properties.VariableNames{'results1'} = 'SubjectID';
results.Properties.VariableNames{'results2'} = 'Session';
results.Properties.VariableNames{'results3'} = 'TrialNumber';
results.Properties.VariableNames{'results4'} = 'Direction';
results.Properties.VariableNames{'results5'} = 'TargetOffset';
results.Properties.VariableNames{'results6'} = 'TargetOffset(arcmin)';
results.Properties.VariableNames{'results7'} = 'Correct';
results.Properties.VariableNames{'results8'} = 'ReactionTime';
writetable(results,fullfile(direcname, file.Raw + ".txt"),'Delimiter','tab');
plot(sc.Hard.Offset)
hold on
plot(sc.Easy.Offset)
title(strcat('Mean response time = ',num2str(mean(timing.rt)),' secs'))
end
