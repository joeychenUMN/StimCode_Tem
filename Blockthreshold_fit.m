clear;

% Read LabChart data
f = adi.readFile('C:\Users\chen8393\Desktop\Data\04082026RVN_Tem.adicht'); % Read file
pres_chanData = f.getChannelByName('ENG'); % Recorded neural signals
pres_chanStim = f.getChannelByName('VNS'); % Stimulation pulse
pres_chanStimkHz = f.getChannelByName('kHz'); % kHz block

% set 2 for preamplifier 2000x/ set 1 for preamplifier 1000x (LabChart unit: mV)
LabChart_Unit = 1; % To convert LabChart unit - V: 1000/ mV: 1
unitPulse = 1; %Stim pulse amplitude unit: 1 for V; 1000 for mV
Conduction_distance = 0.7; %cm

pream_gain = 0.02 /LabChart_Unit;
TrialNum = [39,40,44,46,49,50,53,57,59,62];
Real_kHz_amp = [0,3,4,5];

% Plot all trials
figure(1);
hold on

maxStim = zeros(1, length(TrialNum)); maxStim_kHz = zeros(1, length(TrialNum));
A_AUC = zeros(1, length(TrialNum)); B_AUC = zeros(1, length(TrialNum)); C_AUC = zeros(1, length(TrialNum));
A_PP= zeros(1, length(TrialNum)); B_PP= zeros(1, length(TrialNum)); C_PP= zeros(1, length(TrialNum));

% Sort stimulation Amp
for i = 1:length(TrialNum)

    TrialRead = TrialNum(i);
    
    Pulse = pres_chanStim.getData(TrialRead)/unitPulse;
    Pulse = Pulse - mean(Pulse); %Correct the baseline

    kHz_Pulse = pres_chanStimkHz.getData(TrialRead)/unitPulse;
    kHz_Pulse = kHz_Pulse - mean(kHz_Pulse); %Correct the baseline

    maxStim(i) = max(Pulse);
    maxStim_kHz(i) = max(kHz_Pulse);

end

[maxStim, idx] = sort(maxStim);
[maxStim_kHz, idx_kHz] = sort( maxStim_kHz);
% [maxStim_kHz, idx_kHz] = sort(Real_kHz_amp);

ThresholdFactor = 0.6;
Stim_freq = 3.096; %Hz
Time_before_PositiveP = 20; %ms
threshold = maxStim*ThresholdFactor;

% Generate color map based on the number of trials
colors = jet(length(TrialNum));  % You can also use other colormaps like parula or jet
legendLabels = {};
% Plot all trials signals
for g = 1:length(TrialNum)

    Read_idx = idx_kHz(g); % sort by kHz amp: idx_kHz(g); by trial: g

    TrialRead = TrialNum(Read_idx);
    thresholdRead = threshold(Read_idx);
    fs = pres_chanData.fs(TrialRead);

    % EXTRACT NEURAL SIGNALS
    % Load data
    Pulse = pres_chanStim.getData(TrialRead);
    Pulse = Pulse - mean(Pulse); %Correct the pulse baseline

    % Detect peaks in Pulse
    [PulseValue, PulseTime] = findpeaks(Pulse,'MinPeakHeight',thresholdRead);
    BeforeStimLength = int64(5*fs); % 5 seconds
    ENGLength = round((1/Stim_freq)*fs) - 1500;
    time = (-Time_before_PositiveP*100 : ENGLength-1) / 100; % ms; Based on sampling rate of LabChart equal to 100k/s
    
    action_potential_wbaseline = zeros(1, ENGLength + Time_before_PositiveP*100);
    data = pres_chanData.getData(TrialRead);
    
    %Filter out kHz artifacts
    fc = 3000;  % Cutoff frequency (below the 10 and 20 kHz artifact)
    order = 4;
    [b, a] = butter(order, fc / (fs/2), 'low');
    data = filtfilt(b, a, data);
    
    % Signal base
    Signal_base = data(1:BeforeStimLength);
    PulseTime_len = round(length(PulseTime)); % Adjust the time window for analysis
    
    for i = 5:PulseTime_len-5

        % Extract the data around each detected peak
        current_potential_wbaseline = data(PulseTime(i)- Time_before_PositiveP*100: PulseTime(i)+ ENGLength - 1);
        % Correct baseline
        current_potential_wbaseline = current_potential_wbaseline- mean(Signal_base);
    
        % Accumulate individual action potential and pulse shapes
        action_potential_wbaseline = action_potential_wbaseline + current_potential_wbaseline';

    end

    % Plot action potential
    AvgSignal_wbaseline = (action_potential_wbaseline/(PulseTime_len-10))/pream_gain;
    plot(time, AvgSignal_wbaseline, 'Color', colors(g, :)); % Assign color from colormap

    % Conduction velocity (Berthon et al. 2024; PMID: 38880906) in ms
    CV_A = Conduction_distance/100./[5, 120]*1000; 
    CV_B = Conduction_distance/100./[1.9, 15]*1000;
    CV_C = Conduction_distance/100./[0.4, 1.2]*1000;

    CV_A(2) = 0.8; % To avoid stim artifacts
    CV_B(2) = 0.8; % To avoid stim artifacts

    % Estimate AUC
    [A_PP(g),A_AUC(g)] = Activity_analysis(AvgSignal_wbaseline,CV_A(2),CV_A(1),time);
    [B_PP(g),B_AUC(g)] = Activity_analysis(AvgSignal_wbaseline,CV_B(2),CV_B(1),time);
    [C_PP(g),C_AUC(g)] = Activity_analysis(AvgSignal_wbaseline,CV_C(2),CV_C(1),time);

    % Add amplitude value to legend labels
    legendLabels{g} = [ num2str(round(maxStim(g),2)) '/ ' num2str(round(maxStim_kHz(g),2))];
    % legendLabels{g} = [num2str(TrialRead)];
    
end

% Add legend with amplitude values
legend(legendLabels, 'Location', 'best');
title('Average Action Potential');
xlabel('Time (ms)');
ylabel('Amplitude (uV)');

xline(CV_A,Color='k');
xline(CV_B,Color='r');
xline(CV_C,Color='b');

ylim([-200,200])
xlim([-5,20])

% Relative AUC
A_AUC = A_AUC/max(A_AUC); B_AUC = B_AUC/max(B_AUC); C_AUC = C_AUC/max(C_AUC);
A_PP = A_PP/max(A_PP); B_PP = B_PP/max(B_PP); C_PP = C_PP/max(C_PP);

Data_AUC = [A_AUC; B_AUC; C_AUC]';
Data_PP = [A_PP; B_PP; C_PP]';

Fiber_type = ["A fiber", "B fiber", "C fiber"];
figure(2)
hold on

for i = 1:3

    Measurement_AUC = Data_AUC(1:length(A_AUC),i);
    Measurement_PP = Data_PP(1:length(A_AUC),i);

    subplot(1,3,i)
    hold on
    f_AUC = AmpCurve(maxStim_kHz,Measurement_AUC);
    f_PP = AmpCurve(maxStim_kHz,Measurement_PP);

    yline(0.5,':','HandleVisibility','off','Color','k','LineWidth',2.5);

    plot(maxStim_kHz, feval(f_AUC, maxStim_kHz),':','HandleVisibility','off', 'LineWidth', 2,'Color','k')
    % plot(maxStim_kHz, feval(f_PP, maxStim_kHz),':','HandleVisibility','off', 'LineWidth', 2,'Color','b')

    scatter(maxStim_kHz, Measurement_AUC, 100, 'filled', 'MarkerFaceColor','k','DisplayName','AUC');
    % scatter(maxStim_kHz, Measurement_PP, 100, 'filled', 'MarkerFaceColor','b','DisplayName','Positive peak');

    xlabel('kHz amp (mA)');
    ylabel('Ratio')
    title(Fiber_type(i));
    % legend
end

hold off;
% clear

function [PP,AUC] = Activity_analysis(AvgSignal_wbaseline,Start_time_ms,End_time_ms,time)
    
    % Find the index range corresponding to the time window
    idx_range = find(time >= Start_time_ms & time <= End_time_ms);
    Base_range = 1:length(idx_range);

    % Positive peak amplitude
    PP = max(AvgSignal_wbaseline(idx_range)) - max(AvgSignal_wbaseline(Base_range));

    % AUC
    AUC_baseline = trapz(time(Base_range), abs(AvgSignal_wbaseline(Base_range))); % base AUC
    
    % Compute AUC using the absolute value of the signal in this window
    AUC = trapz(time(idx_range), abs(AvgSignal_wbaseline(idx_range))) - AUC_baseline;

end

function f = AmpCurve(Amp,Measurement)

    % sigmoid model; PMID: 31945746
    ft = fittype(@(a,b,c,x) a ./ (1 + exp(-b*(-x-c))), ...
        'independent','x', ...
        'coefficients', {'a','b','c'});

    Amp = Amp';

    slope_guess = (Measurement(end) - Measurement(1)) / (Amp(end) - Amp(1));
    b0 = abs(slope_guess * 5);  % tune scale factor if needed

    [f, gof] = fit(Amp,Measurement, ft, 'StartPoint', [max(Measurement), b0, median(Amp)]);

end