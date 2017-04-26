%% read files into EEGLAB and save the result
function EEG = readbdf_into_eeglab(filename)
% read in data, subtract EOG, replace trigger values as needed, look up or
% insert channel info

% some specifics
refchannels = {'EXG5' 'EXG6'};
% EOG above / below
horchannels = {'EXG3' 'EXG4'}; % verchannels = {'VEOGsT' 'VEOGsT'}; 
% EOG left / right
verchannels = {'EXG2' 'EXG1' }; % horchannels = {'HEOGsL' 'HEOGsR'}; 
% eeglab path
eeglab_path = [getenv('HOME') filesep 'Documents/matlab_toolboxes/eeglab13_4_4b'];

% add eeglab path
if (~isdeployed)
    addpath(eeglab_path);
end

% load triggers
datapath = filename(1:max(strfind(filename,filesep))-1);
if exist([datapath filesep 'triggercodes.mat'],'file');
    replace_triggers = 1;
    load([datapath filesep 'triggercodes'], 'triggers');
    disp('triggers will be replaced!');
else
    replace_triggers = 0;
end

% read data
if ~strcmpi(filename(end-3:end),'.bdf')
    filename = [filename '.bdf'];
end
if exist(filename,'file')
    disp(filename);
    EEG = pop_biosig(filename); % USE AT VU
    % EEG = pop_readbdf_triggerfix(filename,[],73); % 73/80 refers to the status channel 
    % the tailor made pop_readbdf_triggerfix can be found in my /matlab_scripts/eeg_preprocessing folder
else
    error([datapath filesep filename ' does not seem to exist']);
end

% determine reference channels
ref = [find(strcmpi(refchannels{1},{EEG.chanlocs.labels})) find(strcmpi(refchannels{2},{EEG.chanlocs.labels}))];
if numel(ref) ~= 2
    error('could not find specified reference channels');
end

% re-reference
EEG = pop_reref(EEG, ref, 'refstate','averef');
ver = [ find(strcmpi(verchannels{1},{EEG.chanlocs.labels})) find(strcmpi(verchannels{2},{EEG.chanlocs.labels}))];
hor = [ find(strcmpi(horchannels{1},{EEG.chanlocs.labels})) find(strcmpi(horchannels{2},{EEG.chanlocs.labels}))];

% fix labels
if exist([datapath filesep '68ChanLocsBiosemi.mat'],'file')
    load([datapath filesep '68ChanLocsBiosemi.mat']);
    load([datapath filesep '68ChanInfoBiosemi.mat']);
    EEG.chanlocs = chanlocs;
    EEG.chaninfo = chaninfo;
else
    error('I could not read the external channel files. These should be placed in the source directory together with the BDFs.');
end



% fix triggers if needed
% EEG.event(x).type = condition
% EEG.event(x).latency = sample
if replace_triggers
    EEG.event = EEG.event(1:numel(triggers.(filename)));
    [EEG.event.type] = deal(triggers.(filename).value);
    [EEG.event.latency] = deal(triggers.(filename).sample);
end

% re-reference ocular channels
if numel(hor) ~= 2 || numel(ver) ~= 2
    warning('cannot find horizontal and/or vertical eye channels');
else
    verEyeData = EEG.data(ver(1),:)-EEG.data(ver(2),:);
    horEyeData = EEG.data(hor(1),:)-EEG.data(hor(2),:);
    EEG.data(65,:) = verEyeData;
    EEG.data(66,:) = horEyeData;
    EEG.chanlocs(65).labels = 'VEOG';
    EEG.chanlocs(66).labels = 'HEOG';
    % remove unwanted channels
    EEG.data = EEG.data(1:66,:);
    EEG.chanlocs = EEG.chanlocs(1:66);
    EEG.nbchan = 66;
end

% some bookkeeping
if isfield(EEG.chaninfo,'nodatchans')
    EEG.chaninfo = rmfield(EEG.chaninfo,'nodatchans');
end