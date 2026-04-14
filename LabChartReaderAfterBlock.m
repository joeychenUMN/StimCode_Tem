clear;

% Read LabChart data
f = adi.readFile('C:\Users\chen8393\Desktop\Data\04082026RVN_Tem.adicht'); % Read file
pres_chanData = f.getChannelByName('ENG'); % Recorded neural signals
pres_chanStim = f.getChannelByName('VNS'); % Stimulation pulse
pres_chanStimkHz = f.getChannelByName('kHz'); % kHz block

% set 2 for preamplifier 2000x/ set 1 for preamplifier 1000x (LabChart unit: mV)
LabChart_Unit = 1; % To convert LabChart unit - V: 1000/ mV: 1
pream_gain = 0.02 /LabChart_Unit;
unitPulse = 1; %Stim pulse amplitude unit: 1 for V; 1000 for mV
TrialRead = 128;

conduction_distance = 0.7/100; %cm
Stim_freq = 3.096; %Hz
Time_before_PositiveP = 5; %ms
interval_num_total = 60/ 5; % 5 seconds per interval

Pulse = pres_chanStim.getData(TrialRead)/unitPulse;
PulsekHz = pres_chanStimkHz.getData(TrialRead)/unitPulse;
Pulse = Pulse - mean(Pulse); %Correct the baseline
PulsekHz = PulsekHz - mean(PulsekHz);

maxStim = max(Pulse); maxStimkHz = max(PulsekHz); ThresholdFactor = 0.6;
thresholdRead = maxStim*ThresholdFactor;
thresholdReadkHz = maxStimkHz*ThresholdFactor;
fs = pres_chanData.fs(TrialRead);

% Generate color map based on the number of trials
colors = jet(interval_num_total);  % You can also use other colormaps like parula or jet
legendLabels = {};

figure;
hold on

% Plot all signals
% Detect peaks in Pulse
[PulseValue, PulseTime] = findpeaks(Pulse,'MinPeakHeight',thresholdRead);
[PulseValuekHz, PulseTimekHz] = findpeaks(PulsekHz,'MinPeakHeight',thresholdReadkHz);

% Print the first pulse number after kHz signals turn off
firstPulseAfterkHz = find(PulseTime > max(PulseTimekHz), 1, 'first');
disp(['kHz stop: ', num2str(firstPulseAfterkHz*(1/Stim_freq)), ' s']);

BeforeStimLength = int64((Time_before_PositiveP-1)*1e-3*fs); % -1 ms to avoid artifacts
ENGLength = round((1/Stim_freq)*fs) - 500;
time = ((-Time_before_PositiveP*1e-3*fs) : (ENGLength-1)) * 1000 / fs; % ms; Based on sampling rate of LabChart equal to 100k/s

data = pres_chanData.getData(TrialRead);

% % Filter out kHz artifacts
fc = 3000;
order = 4;
[b,a] = butter(order, fc/(fs/2),'low');
data = filtfilt(b,a,data);

fc_low = 55;
fc_high = 65;
order = 2;
[b,a] = butter(order, [fc_low, fc_high]/(fs/2),'stop');
data = filtfilt(b,a,data);

% Signal base
PulseTime_len = round(length(PulseTime)); % Adjust the time window for analysis
PulseTime_len_interval = fix(PulseTime_len/interval_num_total);

% 5 seconds interval
for interval_num = 1:interval_num_total

    action_potential_wbaseline = zeros(1, ENGLength +Time_before_PositiveP*1e-3*fs);
    
    for i = 1 +(interval_num-1)*PulseTime_len_interval :interval_num *PulseTime_len_interval

        Start_time = PulseTime(i)- Time_before_PositiveP*1e-3*fs;

        % Extract the data around each detected peak
        current_potential_wbaseline = data(Start_time: PulseTime(i)+ ENGLength - 1);
        Signal_base = data(Start_time-BeforeStimLength:Start_time);

        % Correct baseline
        current_potential_wbaseline = current_potential_wbaseline- mean(Signal_base);
    
        % Accumulate individual action potential and pulse shapes
        action_potential_wbaseline = action_potential_wbaseline + current_potential_wbaseline';
    end

    AvgSignal = (action_potential_wbaseline/PulseTime_len_interval)/pream_gain;
    plot(time, AvgSignal, 'Color', colors(interval_num, :), LineWidth=2.5); % Assign color from colormap
    legendLabels{interval_num} = ['Interval: ' , num2str(interval_num)];

end

% Add legend with amplitude values
legend(legendLabels, 'Location', 'best');
title('Average Action Potential');
xlabel('Time (ms)');
ylabel('Amplitude (uV)');
% ylim([-4,3])

% % Shaded region A- B- C-fibers
% Start_time_ms_A = (conduction_distance/120)*1000 - Buffer_time;
% if Start_time_ms_A < 0
%     Start_time_ms_A = max(0, (conduction_distance/120)*1000 - Buffer_time);
% end
% 
% End_time_ms_A   = (conduction_distance/5)*1000 + Buffer_time;
% 
% Start_time_ms_B = (conduction_distance/15)*1000 - Buffer_time;
% End_time_ms_B   = (conduction_distance/3)*1000 + Buffer_time;
% 
% Start_time_ms_C = (conduction_distance/2)*1000 - Buffer_time; % Different from literature
% End_time_ms_C   = (conduction_distance/0.6)*1000 + Buffer_time;
% if End_time_ms_C > 30
%     End_time_ms_C = 30;
% end

hold off

% clear

