function start_sampling_labchart(comment_str)

global gLCApp;
GetLCApp;  %defines global gLCApp
assert(~isempty(gLCApp.ActiveDocument),'Error: In order to run this code, LabChart must be open and you must have an active document open also.')

gLCApp.ActiveDocument.StartSampling(); pause(1)

% Write comment string if applicable
if (exist('comment_str','var') && ~isempty(comment_str))
    gLCApp.ActiveDocument.AppendComment(comment_str,0);
end