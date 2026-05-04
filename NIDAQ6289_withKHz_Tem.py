"""
Signal Generator and LabChart Controller

This module provides functionality for generating various types of signal waveforms
and controlling LabChart data acquisition.

"""

import numpy as np
import math
import time
from matplotlib import pyplot as plt
import datetime
from dataclasses import dataclass
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class SignalParameters:

    """Data class containing signal generation parameters."""

    """" NI-DAQ parameters """
    sample_rate_USB6289: int  # Samples per second (USB-6289 supports higher rates)
    sample_rate_USB6216: int  # Samples per second (USB-6216 max is 250kS/s)

    """Define parameters for VNS biphasic pulse"""
    frequency: float  # Hz
    amplitude: float # Volts
    duration: int    # Seconds
    pulse_width: int # us
    mode: str # 'biphasic' or 'monophasic'
    
    """Partial kHz stimulation parameters"""
    waveform_period_sec: float # kHz frequency
    max_ma: float # mA
    seconds_at_max: int # Seconds
    
    """ complete kHz stimulation parameters"""
    waveform_period_sec_Add: float # kHz frequency
    max_ma_Add: float # mA

    """ resistor kHz stimulation parameters"""
    waveform_period_sec_resistor: float # kHz frequency
    max_ma_resistor: float # mA

class SignalGenerator:
    """Class for generating various types of signal waveforms."""

    def __init__(self, params: SignalParameters):
        """Initialize the SignalGenerator with given parameters."""
        self.params = params
        self._validate_parameters()

    def _validate_parameters(self) -> None:
        """Validate input parameters."""
        if self.params.sample_rate_USB6216 <= 0:
            raise ValueError("Sampling frequency must be positive")
        if self.params.sample_rate_USB6289 <= 0:
            raise ValueError("Sampling frequency must be positive")
        if self.params.max_ma < 0:
            raise ValueError("Maximum amplitude cannot be negative")
        if self.params.waveform_period_sec <= 0:
            raise ValueError("Waveform period must be positive")
        if self.params.mode not in ['biphasic', 'monophasic']:
            raise ValueError("Mode must be 'biphasic' or 'monophasic'")
        if self.params.frequency <= 0:
            raise ValueError("Frequency must be positive")
        # if self.params.amplitude < 0:
        #     raise ValueError("Amplitude cannot be negative")   
        if self.params.pulse_width <= 0:
            raise ValueError("Pulse width must be positive")
        if self.params.duration <= 0:
            raise ValueError("Duration must be positive")

    def partial_kHz_stimulation(self)-> np.ndarray:
        
        """Generate a continuous signal."""
        samples_per_cycle = int(self.params.sample_rate_USB6289 * self.params.waveform_period_sec)
        num_hold_cycles = math.floor(self.params.seconds_at_max / self.params.waveform_period_sec)
        
        total_samples = math.floor(num_hold_cycles) * samples_per_cycle
        time_indices = np.arange(total_samples)

        Partial_kHz_signal = self.params.max_ma*np.sin(2 * np.pi * np.remainder(time_indices, samples_per_cycle) / samples_per_cycle)
        
        return Partial_kHz_signal
    
    def Add_kHz_stimulation(self)-> np.ndarray:
        
        """Generate a continuous signal."""
        samples_per_cycle = int(self.params.sample_rate_USB6289 * self.params.waveform_period_sec_Add)
        num_hold_cycles = math.floor(self.params.seconds_at_max / self.params.waveform_period_sec_Add)
        
        total_samples = math.floor(num_hold_cycles) * samples_per_cycle
        time_indices = np.arange(total_samples)

        Add_kHz_signal = self.params.max_ma_Add*np.sin(2 * np.pi * np.remainder(time_indices, samples_per_cycle) / samples_per_cycle)
        
        return Add_kHz_signal
    
    def resistor_kHz_stimulation(self)-> np.ndarray:
        
        """Generate a continuous signal."""
        samples_per_cycle = int(self.params.sample_rate_USB6216 * self.params.waveform_period_sec_resistor)
        num_hold_cycles = math.floor(self.params.seconds_at_max / self.params.waveform_period_sec_resistor)
        
        total_samples = math.floor(num_hold_cycles) * samples_per_cycle
        time_indices = np.arange(total_samples)

        resistor_kHz_signal = self.params.max_ma_resistor*np.sin(2 * np.pi * np.remainder(time_indices, samples_per_cycle) / samples_per_cycle)
        
        return resistor_kHz_signal

    def generate_biphasic_pulse(self)-> np.ndarray:    
        """Generate a biphasic pulse signal with a given frequency."""
        num_samples = int(self.params.sample_rate_USB6289 * self.params.duration)
        signal = np.zeros(num_samples)

        # Use time-based modulo to create the repetitive pattern
        t = np.linspace(0, self.params.duration, num_samples, endpoint=False)
        cycle_time = t % (1 / self.params.frequency)

        pulse_width_s = self.params.pulse_width * 1e-6

        if self.params.mode == 'biphasic':
            # Vectorized assignment
            signal[cycle_time < pulse_width_s] = self.params.amplitude
            signal[(cycle_time >= pulse_width_s) & (cycle_time < 2 * pulse_width_s)] = -self.params.amplitude
            
            """Check charge balance"""
            if not np.isclose(np.sum(signal), 0, atol=1e-6):
                raise ValueError("Signal is not charge balanced")
        
        else:
            # Vectorized assignment
            signal[cycle_time < pulse_width_s] = self.params.amplitude
                    
        return signal
    
class LabChartController:
    """Class for controlling LabChart data acquisition."""

    def __init__(self, matlab_scripts_path: str, matlab_engine=None):
        """Initialize LabChart controller.
        
        Args:
            matlab_scripts_path: Absolute path to directory containing MATLAB helper scripts
                (e.g., 'Z:/Grill_Lab_Files/Grill_Lab_Analysis_Code_and_Data/code/my_projects/nerve_block_experiment_code')
            matlab_engine: Optional pre-initialized MATLAB engine
        """
        self.matlab_scripts_path = matlab_scripts_path
        self.matlab_engine = matlab_engine or self._start_matlab_engine()

    def _start_matlab_engine(self):
        """Start MATLAB engine and configure paths."""
        import matlab.engine
        eng = matlab.engine.start_matlab()
        eng.cd(self.matlab_scripts_path)
        return eng

    def start_recording(self, comment: str) -> None:
        """Start LabChart recording with comment."""
        self.matlab_engine.start_sampling_labchart(comment, nargout=0)

    def stop_recording(self) -> None:
        """Stop LabChart recording and save data."""
        self.matlab_engine.stop_sampling_and_save_labchart(nargout=0)

    def notify_completion(self) -> None:
        """Play completion notification sounds."""
        for _ in range(3):
            self.matlab_engine.custom_beep(nargout=0)
            time.sleep(1)

    def cleanup(self) -> None:
        """Clean up MATLAB engine."""
        if self.matlab_engine:
            self.matlab_engine.quit()
            
class DAQController:
    
    """Class for controlling National Instruments DAQ."""
    
    def stimulate_with_NIDAQ(self,
                             Primary_rate: int,
                             Secondary_rate: int,
                             signal_with_zero: np.ndarray,
                             Partial_kHz_signal_with_zero: np.ndarray,
                             resistor_kHz_signal_with_zero: np.ndarray,
                             run_Tem_resistor: bool
                             ) -> None:
        
        
        # 1. Determine the maximum length required for Dev2
        max_len_dev2 = max(len(signal_with_zero), len(Partial_kHz_signal_with_zero))

        # 2. Pad signal_with_zero if it is shorter
        if len(signal_with_zero) < max_len_dev2:
            padding_size = max_len_dev2 - len(signal_with_zero)
            signal_with_zero = np.pad(signal_with_zero, (0, padding_size), 'constant')

        # 3. Pad Partial_kHz_signal_with_zero if it is shorter
        elif len(Partial_kHz_signal_with_zero) < max_len_dev2:
            padding_size = max_len_dev2 - len(Partial_kHz_signal_with_zero)
            Partial_kHz_signal_with_zero = np.pad(Partial_kHz_signal_with_zero, (0, padding_size), 'constant')

        """
        Synchronously stimulates two separate NIDAQ devices (Dev2 Primary, Dev1 Secondary).
        All input signals MUST be resampled to the common Primary_rate.
        """
        import nidaqmx
        from nidaqmx.constants import AcquisitionType
        
        print("Configuring two DAQ tasks for synchronous output...")

        ''' --- Start Tasks --- '''
        with nidaqmx.Task("PrimaryTask_6289") as Primary_task, \
             nidaqmx.Task("SecondaryTask_6216") as Secondary_task:

            """Configure the analog output channel"""
            # Primary TASK (Dev2/USB-6289): VNS & kHz stimulation
            Primary_task.ao_channels.add_ao_voltage_chan('Dev2/ao0')
            Primary_task.ao_channels.add_ao_voltage_chan('Dev2/ao1')

            # Secondary TASK (Dev1/USB-6216): add heat by resistor
            Secondary_task.ao_channels.add_ao_voltage_chan('Dev1/ao0') 

            """Configure the timing for the task"""
            Primary_task.timing.cfg_samp_clk_timing(rate=Primary_rate,sample_mode=AcquisitionType.FINITE, samps_per_chan=len(signal_with_zero))
            Secondary_task.timing.cfg_samp_clk_timing(rate=Secondary_rate,sample_mode=AcquisitionType.FINITE, samps_per_chan=len(resistor_kHz_signal_with_zero))
 
            """"Write the signal to the output buffer"""
            if run_Tem_resistor:
                Secondary_task.write(resistor_kHz_signal_with_zero, auto_start=True)
                print("Secondary Task (Dev1) started")

                Primary_task.write(np.vstack((signal_with_zero, Partial_kHz_signal_with_zero)), auto_start=True)
                print("Primary Task (Dev2) started")

                Secondary_task.wait_until_done(timeout=700)
                Primary_task.wait_until_done(timeout=700)

                Secondary_task.stop()
                Primary_task.stop()

            else:
                Primary_task.write(np.vstack((signal_with_zero, Partial_kHz_signal_with_zero)), auto_start=True)
                print("Primary Task (Dev2) started")

                Primary_task.wait_until_done(timeout=700)
                Primary_task.stop()
            
            print("Stimulation period complete. Tasks stopping...")
        
        # Tasks are automatically stopped/cleared by the 'with' context manager
        print("DAQ tasks cleared.")
        
def run_experiment(params: SignalParameters, 
                  matlab_scripts_path: str,
                  run_daq: bool = True,
                  run_kHz: bool = True,
                  run_Tem_highFreq: bool = True,
                  run_Tem_resistor: bool = True,
                  ) -> np.ndarray:
    
    """Main function to run the experiment.
    
    Args:
        params: Signal generation parameters
        matlab_scripts_path: Absolute path to MATLAB helper scripts directory
        run_daq: Whether to run the DAQ or just return the signal
    
    Returns:
        np.ndarray: Generated signal waveform
    """
    # Generate signal
    generator = SignalGenerator(params)
    
    signal = generator.generate_biphasic_pulse()
    Partial_kHz_signal_short = generator.partial_kHz_stimulation()
    Add_kHz_signal_short = generator.Add_kHz_stimulation()
    resistor_kHz_signal_short = generator.resistor_kHz_stimulation()

    if run_Tem_highFreq:
        Partial_kHz_signal_short = Partial_kHz_signal_short[0:len(Add_kHz_signal_short)] + Add_kHz_signal_short

    Add_zeros_vns = np.zeros(10000)
    Add_zeros_kHz = Add_zeros_vns
    Add_zeros_kHz_resist = np.zeros(int(len(Add_zeros_vns) * (params.sample_rate_USB6216 / params.sample_rate_USB6289)))

    signal_with_zero = np.append(signal, Add_zeros_vns)
    resistor_kHz_signal_with_zero = np.append(resistor_kHz_signal_short, Add_zeros_kHz_resist)
    
    if run_kHz:
        Partial_kHz_signal_with_zero = np.append(Partial_kHz_signal_short, Add_zeros_kHz)

    else:
        Partial_kHz_signal = np.zeros(int(params.sample_rate_USB6289 * params.duration))
        Partial_kHz_signal_with_zero = np.append(Partial_kHz_signal, Add_zeros_kHz)

    if not run_daq:
        
        """ Plot the biphasic pulse signal"""
        # let the following plots overlap
        plt.figure()
        plt.plot(signal_with_zero) 
        
        """ Plot the partial kHz signal"""
        plt.figure()
        plt.plot(Partial_kHz_signal_with_zero)

        plt.show()
        
    else:
        # Initialize controllers
        labchart = LabChartController(matlab_scripts_path=matlab_scripts_path)
        daq = DAQController()
        
        # Start recording
        comment = _generate_trial_comment(params, run_kHz = run_kHz, run_Tem_highFreq=run_Tem_highFreq, run_Tem_resistor=run_Tem_resistor)
        labchart.start_recording(comment)
        
        # Allow time for baseline
        time.sleep(5)  # 5 seconds baseline
        
        # Output signal
        daq.stimulate_with_NIDAQ(
            Primary_rate=params.sample_rate_USB6289,
            Secondary_rate=params.sample_rate_USB6216,
            signal_with_zero=signal_with_zero,
            Partial_kHz_signal_with_zero=Partial_kHz_signal_with_zero,
            resistor_kHz_signal_with_zero=resistor_kHz_signal_with_zero,
            run_Tem_resistor = run_Tem_resistor
        )
        
        # Allow time for baseline
        time.sleep(10)  # 10 seconds baseline

        # Post-processing
        labchart.notify_completion()
        labchart.stop_recording()

        labchart.cleanup()

def _generate_trial_comment(params: SignalParameters,
                            run_kHz: bool,
                            run_Tem_highFreq: bool,
                            run_Tem_resistor: bool
                            ) -> str:
    
    """Generate a trial comment string."""
    now = datetime.datetime.now()

    if run_kHz:
        comment = f"Trial: {now.strftime('%Y-%m-%d %H:%M:%S')} - VNS: {params.amplitude}V, Frequency: {params.frequency}Hz, Pulse Width: {params.pulse_width}us, kHz: {params.max_ma}mA, Frequency: {np.floor(1/params.waveform_period_sec)/1000}kHz"

        if run_Tem_highFreq:
            comment = f"Trial: {now.strftime('%Y-%m-%d %H:%M:%S')} - VNS: {params.amplitude}V, Frequency: {params.frequency}Hz, Pulse Width: {params.pulse_width}us, kHz: {params.max_ma}mA, Frequency: {np.floor(1/params.waveform_period_sec)/1000}kHz, Add High freq.: {params.max_ma_Add}mA, Frequency: {np.floor(1/params.waveform_period_sec_Add)/1000}kHz"

        if run_Tem_resistor:
            comment = f"Trial: {now.strftime('%Y-%m-%d %H:%M:%S')} - VNS: {params.amplitude}V, Frequency: {params.frequency}Hz, Pulse Width: {params.pulse_width}us, kHz: {params.max_ma}mA, Frequency: {np.floor(1/params.waveform_period_sec)/1000}kHz, Add resistor.: {params.max_ma_resistor}mA"

    else:
        comment = f"Trial: {now.strftime('%Y-%m-%d %H:%M:%S')} - VNS: {params.amplitude}V, Frequency: {params.frequency}Hz, Pulse Width: {params.pulse_width}us"

    return comment