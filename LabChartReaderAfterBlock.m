% Read LabChart data
f = adi.readFile('C:\Users\chen8393\Desktop\Data\04082026RVN_Tem.adicht'); % Read file
pres_chanData = f.getChannelByName('ENG'); % Recorded neural signals
pres_chanStim = f.getChannelByName('VNS'); % Stimulation pulse
pres_chanHR = f.getChannelByName('Heart Rate');

% Plot all trials
figure;
hold on

% Initial analysis parameters
TrialNum = [128];
maxStim = zeros(1, length(TrialNum));
unitPulse = 1; %Stim pulse amplitude unit: 1 for V; 1000 for mV
conduction_distance = 0.7/100; %cm

Buffer_time = 0.5;

% Sort stimulation Amp
for i = 1:length(TrialNum)

    TrialRead = TrialNum(i);
    
    Pulse = pres_chanStim.getData(TrialRead)/unitPulse;
    Pulse = Pulse - Pulse(1); %Correct the baseline

    maxStim(i) = max(Pulse);

end

[maxStim, idx] = sort(maxStim);

ThresholdFactor = 0.6;
threshold = maxStim*ThresholdFactor;
%%
% Generate color map based on the number of trials
colors = jet(length(TrialNum));  % You can also use other colormaps like parula or jet
legendLabels = {}; HRChangePercent = [];

% Plot all trials signals
for g = 1:length(TrialNum)

    action_potential = zeros(1, 3000);
    action_potential_10 = zeros(1, 3000);
    action_potential_20 = zeros(1, 3000);
    action_potential_30 = zeros(1, 3000);
    action_potential_40 = zeros(1, 3000);
    action_potential_50 = zeros(1, 3000);
    action_potential_60 = zeros(1, 3000);
    Pulse_train = zeros(1, 3000);
    
    TrialRead = TrialNum(idx(g));

    % Load data
    Pulse = pres_chanStim.getData(TrialRead)/unitPulse;
    Raw_data = pres_chanData.getData(TrialRead);

    fs = 10^5;
    fc = 3000;
    order = 4;
    [b,a] = butter(order, fc/(fs/2),'low');
    data = filtfilt(b,a,Raw_data);

    Pulse = Pulse - Pulse(1); %Correct the baseline

    % Detect peaks in Pulse
    [PulseValue, PulseTime] = findpeaks(Pulse,'MinPeakHeight',threshold(g));
    [NPulseValue, NPulseTime] = findpeaks(-Pulse,'MinPeakHeight',threshold(g));

    % length(PulseTime) % check the number of pulse is correct
    
    % Loop through peaks to find the zero index before each peak
    zeros_before_peaks = zeros(size(PulseTime));  % Pre-allocate for indices
    PulseTime_len = round(length(PulseTime)); % Adjust the time window for analysis
    
    for i = 1:PulseTime_len
    
        zero_crossings = Pulse((PulseTime(i))-100:PulseTime(i));

        % Find zero crossing index closest to but before each Pulse peak
        zero_before_peak_idx = find(diff(zero_crossings) < 0.0001, 1,"last");
        
        if ~isempty(zero_before_peak_idx)
            zeros_before_peaks(i) = PulseTime(i)-100 + zero_before_peak_idx;
            
            % Check that the window around the peak fits within the data
            if zeros_before_peaks(i) + 2999 <= length(data)
    
                % Extract the data around each detected peak
                current_potential = data(zeros_before_peaks(i): zeros_before_peaks(i) + 2999);
    
                time = (0:length(current_potential)-1) / 100; % ms; Based on sampling rate of LabChart equal to 100k/s
                
                if i <= 30
                    action_potential_10 = action_potential_10 + current_potential';
                elseif i > 30  && i <= 60
                    action_potential_20 = action_potential_20 + current_potential';
                elseif i > 60 && i <= 90
                    action_potential_30 = action_potential_30 + current_potential';
                elseif i > 90 && i <= 120
                    action_potential_40 = action_potential_40 + current_potential';
                elseif i > 120 && i <= 150
                    action_potential_50 = action_potential_50 + current_potential';
                elseif i > 150
                    action_potential_60 = action_potential_60 + current_potential';
                end

                % if i == 1 || i == 30 || i == 60 || i == 90 || i == 120 || i == 150 || i == 180
                %     plot(time, current_potential/(2/1000), LineWidth=1.5); % Assign color from colormap
                % end

                % Accumulate individual action potential and pulse shapes
                if i <= PulseTime_len/2
                    action_potential = action_potential + current_potential';
                end

                Pulse_train = Pulse_train + Pulse(zeros_before_peaks(i): zeros_before_peaks(i) + 2999)';
   
            end
        end
    end

    % set 2 for preamplifier 2000x/ set 1 for preamplifier 1000x (LabChart unit: mV)
    LabChart_Unit = 1000; % To convert LabChart unit - V: 1000/ mV: 1
    pream_gain = 2 /LabChart_Unit;

    % Plot action potential
    % AvgSignal = (action_potential/(PulseTime_len/2))/pream_gain;

    % Interval average
    AvgSignal_10 = (action_potential_10/30)/pream_gain;
    AvgSignal_20 = (action_potential_20/30)/pream_gain;
    AvgSignal_30 = (action_potential_30/30)/pream_gain;
    AvgSignal_40 = (action_potential_40/30)/pream_gain;
    AvgSignal_50 = (action_potential_50/30)/pream_gain;
    AvgSignal_60 = (action_potential_60/(PulseTime_len - 150))/pream_gain;

    [zero_before_peak_idx_HR, zero_end_peak_idx_HR] = IdxforHR(Pulse,PulseTime,NPulseTime);
    [HRChangePercentGet] = HRcal(pres_chanHR,TrialRead,zero_before_peak_idx_HR, zero_end_peak_idx_HR);
    HRChangePercent = [HRChangePercent; HRChangePercentGet];

    % plot(time, AvgSignal, 'Color', colors(g, :), LineWidth=3.5); % Assign color from colormap
    plot(time, action_potential_10, LineWidth=1.5, DisplayName='0 - 10 seconds');
    plot(time, action_potential_20, LineWidth=1.5, DisplayName='10 - 20 seconds');
    plot(time, action_potential_30, LineWidth=1.5, DisplayName='20 - 30 seconds');
    plot(time, action_potential_40, LineWidth=1.5, DisplayName='30 - 40 seconds');
    plot(time, action_potential_50, LineWidth=1.5, DisplayName='40 - 50 seconds');
    plot(time, action_potential_60, LineWidth=1.5, DisplayName='50 - 60 seconds');

    % Add amplitude value to legend labels
    % legendLabels{g} = [ num2str(round(maxStim(g),2)) ' mA'];
    % legendLabels{g} = [ num2str(TrialRead)];
end

% Add legend with amplitude values
legend(legendLabels, 'Location', 'best');
title('Average Action Potential');
xlabel('Time (ms)');
ylabel('Amplitude (uV)');
ylim([-4,3])

% Shaded region A- B- C-fibers
Start_time_ms_A = (conduction_distance/120)*1000 - Buffer_time;
if Start_time_ms_A < 0
    Start_time_ms_A = max(0, (conduction_distance/120)*1000 - Buffer_time);
end

End_time_ms_A   = (conduction_distance/5)*1000 + Buffer_time;

Start_time_ms_B = (conduction_distance/15)*1000 - Buffer_time;
End_time_ms_B   = (conduction_distance/3)*1000 + Buffer_time;

Start_time_ms_C = (conduction_distance/2)*1000 - Buffer_time; % Different from literature
End_time_ms_C   = (conduction_distance/0.6)*1000 + Buffer_time;
if End_time_ms_C > 30
    End_time_ms_C = 30;
end


% y_limits = [-250,250];
% 
% fill([End_time_ms_A End_time_ms_A Start_time_ms_A Start_time_ms_A], ...
%  [y_limits(1) y_limits(2) y_limits(2) y_limits(1)], ...
%  'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% 
%  fill([End_time_ms_B End_time_ms_B Start_time_ms_B Start_time_ms_B], ...
%  [y_limits(1) y_limits(2) y_limits(2) y_limits(1)], ...
%  'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% 
%  fill([End_time_ms_C End_time_ms_C Start_time_ms_C Start_time_ms_C], ...
%  [y_limits(1) y_limits(2) y_limits(2) y_limits(1)], ...
%  'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');


hold off

figure
scatter(maxStim,HRChangePercent)

function [zero_before_peak_idx, zero_end_peak_idx] = IdxforHR(Pulse,PulseTime,NPulseTime)

    HRfps = 50; % Heart rate sampling freqz (50 samples/ sec).
    Stimfps = 10^5; % Stim channel sampling freqz (100k samples/ sec).

    % Detect zero crossings in the Pulse signal
    zero_crossings = find(diff((Pulse)) ~= 0.0001);  % Indices where Pulse crosses zero

    % Find zero crossing index closest to but before each Pulse peak
    zero_before_peak_idx = find(zero_crossings < PulseTime(1), 1, 'last')-1;
    zero_end_peak_idx = find(zero_crossings > NPulseTime(end), 1, 'first')+1;
    
    % Convert sampling rate
    zero_before_peak_idx = round((zero_crossings(zero_before_peak_idx)/Stimfps)*HRfps)-1;
    zero_end_peak_idx = round((zero_crossings(zero_end_peak_idx)/Stimfps)*HRfps)-1;

end

function [HRChangePercent] = HRcal(pres_chanHR,TrialRead,zero_before_peak_idx, zero_end_peak_idx)

    BufferTime = 250; % Time after stimulation (5 seconds)/ HR sampling rate (50 samples/secs)
    dataHR = pres_chanHR.getData(TrialRead); % Read HR data

    % HR data
    Init_HR = round(mean(dataHR(zero_before_peak_idx-BufferTime:zero_before_peak_idx))); % HR before the stimulation (for a second)

    % Identify HR decrease/ increase due to VNS
    AfterStimHR = round(mean(dataHR(zero_end_peak_idx: zero_end_peak_idx +BufferTime))); % HR after stimulation
    AnalyzeWindow = dataHR(zero_before_peak_idx:zero_end_peak_idx+BufferTime);

    if AfterStimHR > Init_HR % HR increase 
        [MaxValue, MaxIdx] = max(AnalyzeWindow);
        HRChangePercent = ((MaxValue - Init_HR)/Init_HR)*100;
       
    elseif AfterStimHR < Init_HR % HR decrease
        [MinValue, MinIdx] = min(AnalyzeWindow);
        HRChangePercent = ((MinValue - Init_HR)/Init_HR)*100;
        
    else % HR does not change
        HRChangePercent = 0;
    end

end


% clear

