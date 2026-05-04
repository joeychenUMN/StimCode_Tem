% addpath('adinstruments_sdk_matlab')

filename = 'tp_prime_calibration_data_with_physitemp_vs_somnosuite.adicht';

f = adi.readFile(filename);
TL_301_T_type_thermocouple = f.getChannelByName('Channel 5');
somno_suite_thermocouple = f.getChannelByName('Pad Temp');

CALIBRATION_TRIAL_IDX = 21;
calibration_data_somno_suite = somno_suite_thermocouple.getData(CALIBRATION_TRIAL_IDX);
somnosuite_fs = round(somno_suite_thermocouple.fs(CALIBRATION_TRIAL_IDX));
somno_suite_time = ((1:length(calibration_data_somno_suite))-1)/somnosuite_fs; % [sec]


GAIN = 1e3; % gain factor on the SR560 analog front-end
UNITS_OF_TL_301 = 1e-3; % [mV] need to factor this into calibration
assert(strcmp(TL_301_T_type_thermocouple.units{CALIBRATION_TRIAL_IDX},'mV'))
calibration_data_TL_301 = TL_301_T_type_thermocouple.getData(CALIBRATION_TRIAL_IDX);
% Get true V units by accounting for front-end gain and PowerLab units
calibration_data_TL_301 = calibration_data_TL_301/GAIN*UNITS_OF_TL_301;
TL_301_fs = round(TL_301_T_type_thermocouple.fs(CALIBRATION_TRIAL_IDX));
TL_301_time = ((1:length(calibration_data_TL_301))-1)/TL_301_fs; % [sec]

% exclude times after 295 s because the TL_301 input range was exceeded for
% the particular settings used
TIME_EXCLUSION_SEC = 295; % [sec]
calibration_data_TL_301(TL_301_time>TIME_EXCLUSION_SEC) = [];
TL_301_time(TL_301_time>TIME_EXCLUSION_SEC) = [];
calibration_data_somno_suite(somno_suite_time>TIME_EXCLUSION_SEC) = [];
somno_suite_time(somno_suite_time>TIME_EXCLUSION_SEC) = [];

% clean up the somno_suite data a bit using movmedian, since it has random
% very large noise points, so movmean is not appropriate
time_window_for_smoothing_sec = 5; % [sec]
calibration_data_somno_suite_movmedian = movmedian(calibration_data_somno_suite,time_window_for_smoothing_sec*somnosuite_fs);

% Plot smoothing results
figure; 
plot(somno_suite_time,calibration_data_somno_suite); 
hold on;
plot(somno_suite_time,calibration_data_somno_suite_movmedian);
xlabel('time (sec)')
ylabel('temp (deg C)')

legend('raw','movmedian')
%%
% Plot overlay of thermocouple outputs before calibrating
figure; 
plot(somno_suite_time,calibration_data_somno_suite_movmedian);
yyaxis right
ylabel('temp (deg C)')
plot(TL_301_time,1e6*calibration_data_TL_301); 
ylabel('thermocouple voltage (uV)')
xlabel('time (sec)')

% Interpolate the values from TL 301 which are smapled with much higher
% time resoltion; this will enable calibration curve
calibration_data_TL_301_interpolated = interp1(TL_301_time,calibration_data_TL_301,somno_suite_time);

% Define now a common time vector
time = somno_suite_time; % [sec]

% Plot calibration curve
figure('color',[1 1 1]);
plot(1e6*calibration_data_TL_301_interpolated,calibration_data_somno_suite_movmedian,'.','MarkerSize',10);

% Fit a line and overlay the line fit on the curve
calibration_line_poly = polyfit(calibration_data_TL_301_interpolated,calibration_data_somno_suite_movmedian, 1); 
format long
disp(calibration_line_poly)
hold on;
x_eval = linspace(min(calibration_data_TL_301_interpolated),max(calibration_data_TL_301_interpolated));
plot(1e6*x_eval,polyval(calibration_line_poly,x_eval),'k--');
xlabel('thermocouple voltage (\muV)')
ylabel('temp (deg C)')
title(sprintf('y = %0.3e*x + %0.3e',calibration_line_poly))
set(gca,'FontSize',14)
legend('raw','fit')


%% Plot target illustrative trials in deg C


trials_to_plot = [10, 11, 13]; % 10, 20, 40 kHz at 6 mA
stim_end_time = [48.1, 63.8, 41.2]; % specify the time stim ended to align the trials
legend_str = {'10 kHz','20 kHz','40 kHz'};
title_str = '6 mA';

trials_to_plot = [18, 17, 10]; % 10 kHz at 2 and 4 mA
stim_end_time = [52.24, 42.55, 48.253]; % specify the time stim ended to align the trials
legend_str = {'2 mA', '4 mA','6 mA'};
title_str = '10 kHz';

% for each trial, load the trial, convert the units, then plot as an
% overlay
figure('color',[1 1 1]);
for trial_idx = 1:length(trials_to_plot)
    data_i = TL_301_T_type_thermocouple.getData(trials_to_plot(trial_idx));
    % Get true V units by accounting for front-end gain and PowerLab units
    data_i = data_i/GAIN*UNITS_OF_TL_301;
    data_fs = round(TL_301_T_type_thermocouple.fs(CALIBRATION_TRIAL_IDX));
    data_time = ((1:length(data_i))-1)/TL_301_fs; % [sec]

    % shift the time by the stim end time, then arbitrary define -35
    % seconds as zero since all stim was 30 sec long
    ZERO_TIME_RELATIVE_TO_STIM_END = 35; % [sec]
    data_time = data_time - stim_end_time(trial_idx) + ZERO_TIME_RELATIVE_TO_STIM_END;


    % Convert the units
    data_i_degC = polyval(calibration_line_poly,data_i);

    % Finally, subtract the baseline so that the results are in *change* in
    % temp
    BASELINE_WINDOW = 3; 
    data_i_degC = data_i_degC - mean(data_i_degC(data_time<BASELINE_WINDOW));

    % Plot the overlay
    plot(data_time, data_i_degC,'linewidth',2);
    hold on;
end

legend(legend_str)
ylabel('\DeltaT (deg C)')
xlabel('time (s)')
title(title_str)
set(gca,'FontSize',14)

%%
% Read LabChart data
figure;
hold

f = adi.readFile('C:\Users\chen8393\Desktop\Add_Tem_resistor_test.adicht'); % Read file
pres_chanData = f.getChannelByName('Couple'); % Recorded neural signals

trial_idx = 32;
tem_data = pres_chanData.getData(trial_idx);

% Get true V units by accounting for front-end gain and PowerLab units
data_i = tem_data/(2e3);
data_fs = round(TL_301_T_type_thermocouple.fs(CALIBRATION_TRIAL_IDX));
data_time = ((1:length(data_i))-1)/TL_301_fs; % [sec]

% Convert the units
data_i_degC = polyval(calibration_line_poly,data_i);

plot(data_i_degC)