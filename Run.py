"""
Example script demonstrating basic usage of the signal generator and LabChart controller.

This script shows how to:
1. Generate a biphasic pulse and kHz stimulation signal
2. Run a complete experiment with DAQ and LabChart integration
"""

import sys
from pathlib import Path

# Add parent directory to Python path to import the main script
parent_dir = str(Path(__file__).resolve().parent.parent)
sys.path.append(parent_dir)

from NIDAQ6289_withKHz_Tem import (
    SignalParameters,
    run_experiment,
)

def main():
    # User should modify this path to match their system setup
    MATLAB_SCRIPTS_PATH = r'C:\Users\chen8393\Desktop\ThreeStim_Tem'  # Update this path

    # kHZ stimulation end  too early (a bug in the code 09/30/25)
    # the reason that the khz duration is set to 6 seconds is that the kHz stimulation
    # needs to be longer than the biphasic pulse duration (5 seconds) to ensure
    params = SignalParameters(

        # NI-DAQ parameters
        sample_rate_USB6289 = 2000000,  # Samples per second (USB-6289 supports higher rates)
        sample_rate_USB6216 = 250000,  # Samples per second (USB-6216 max is 250kS/s)
        
        # Biphasic pulse parameters
        frequency = 3.096,  # Hz
        amplitude = 5, # Volts
        duration = 10.0,  # Seconds
        pulse_width = 16, # us
        mode = 'biphasic', # 'biphasic' or 'monophasic'

        # kHz stimulation parameterss
        waveform_period_sec= 1e-4, # 10 kHz frequency
        # waveform_period_sec= 5e-5, # 20 kHz frequency
        max_ma= 0, #mA
        seconds_at_max= 30, # Seconds

        # Add temperature by kHz stimulation parameters
        # waveform_period_sec_Add= 2.5e-5, # 40 kHz frequency
        # waveform_period_sec_Add= 1.25e-5, # 80 kHz frequency
        waveform_period_sec_Add= 1e-5, # 100 kHz frequency
        max_ma_Add= 0, # mA

        # Add temperature by resistor
        waveform_period_sec_resistor= 5e-5, # kHz frequency
        max_ma_resistor= 9, # mA
    )

    run_experiment(
        params=params,
        matlab_scripts_path=MATLAB_SCRIPTS_PATH,
        run_daq= True,     # run stimulation

        run_kHz= False,      # Include kHz signal

        run_Tem_highFreq= False,
        run_Tem_resistor= False
    )

    print("Saved signals from experiment.")


if __name__ == "__main__":
    main()