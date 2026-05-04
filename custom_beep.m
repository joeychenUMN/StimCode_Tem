
function custom_beep()
beep_freq_Hz    = 1500; % [Hz]
duration_sec    = 0.1; % [sec]
Fs_Hz           = 22050; % [Hz]
t_sec           = 0:(1/Fs_Hz):duration_sec; % [sec]
sound(sin(2*pi*beep_freq_Hz*t_sec),Fs_Hz);
end