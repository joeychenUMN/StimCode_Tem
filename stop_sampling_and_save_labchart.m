
function stop_sampling_and_save_labchart()

global gLCApp;
GetLCApp;  %defines global gLCApp
assert(~isempty(gLCApp.ActiveDocument),'Error: In order to run this code, LabChart must be open and you must have an active document open also.')

gLCApp.ActiveDocument.StopSampling(); % stop LabChart sampling
gLCApp.ActiveDocument.Save();
