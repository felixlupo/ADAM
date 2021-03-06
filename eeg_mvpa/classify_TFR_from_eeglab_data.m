function classify_TFR_from_eeglab_data(filepath,filenames,outpath,nFolds,channelset,method,crossclass_and_or_resample,tf_and_erp_baseline,frequencies,varargin)
% function classify_TFR_from_eeglab_data(filepath,filenames,outpath,nFolds,channelset,method,crossclass_and_or_resample,tf_and_erp_baseline,frequencies,varargin)
% Wrapper function to do TFR extraction and MVPA classification in one
% step, replacing the function classify_TFR_data_from_eeglab.m and
% classify_TFR_data.m which contained flaws when doing classification on
% induced data. This function references compute_TFR_from_eeglab.m See help
% for this  function to learn more about the TFR input parameters to method
% (which can also contain values like 'total', 'induced' or 'evoked').
% filenames either contains a single filename for testing and training, or
% two filenames separated by a comma (the first for training, second for
% testing)
% outpath contains the folder where results should be stored (if empty
% defaults to filepath)
% nFolds is the number of cohorts in which the data is split up for
% the leave-one-out procedure (only when the same data are used for
% training and testing). If there are separate sets for testing and
% training, nFolds defaults to 1. In that case, testing and training
% need to contain the same trigger codes, or you need to specify separate
% trigger codes for the testing set by separating by a semicolon (see
% below).
% channelset determines the electrode subset that is used for testing. This
% can be done either numerically (assumes a 64 channel 10-20 system):
% 1 (uses all electrodes)
% 2 (uses occipital electrodes)
% 3 (uses parietal electrodes)
% 4 (uses frontal electrodes)
% 5 (uses temporal electrodes)
% 6 (uses occipitoparietal electrodes)
%
% method specifies the method used for classification. Default is 'linear'
% for linear discriminant analysis. Other options are: 'diagLinear',
% 'mahalanobis' or 'quadratic'.
% The dependent classification measure can be specified in method,
% either using 'accuracy' (default), 'hr-far' or 'dprime' (last two only
% work when two categories are present, the first category is assumed to be
% the target present category, the second the target absent category. If
% more than two categories are present, the script defaults back to
% accuracy. If you want to output the individual labels that were assigned
% by the classifier to each of the trials rather than computing accuracy,
% specify 'labelsonly'. In this case, the algorithm goes through the entire
% training set and outputs a label for each trial. No accuracy scores will
% be computed in this case.
% Specify by adding to method, e.g. like this:
% method = 'linear,hr-far'
% If you want to output the individual labels that were assigned
% by the classifier to each of the trials rather than computing accuracy,
% specify 'labelsonly'. If no conditions are specified for the testing set,
% the algorithm goes through the entire testing set and outputs a label for
% each time point in each trial. No accuracy scores will be computed in
% this case. If conditions are specified for the test set, only conditions
% fitting this specification are labeled.
% In method you can also specify that the training labels should be
% permuted under random permutation by adding 'randperm', separated by a
% comma, like this: method = 'linear,randperm'. The results of computing
% under random permutation are stored in a folder called 'randperm' and can
% subsequently be used for hypothesis testing.
% Similarly, you can also run another complete iteration of the same data
% (all folds) without randomly permuting the labels, by specificying
% method = 'iterate'. The results of computing another iteration are stored
% in a folder called 'iterations' and can subsequently be used for
% averaging to get a cleaner result.
% You can specify the number of times you want to execute a permutation or
% iteration through the create_qsub_files function, by setting the number
% of repeats using settings.repeat as an argument to that function.
% In method, you can also specify whether the trial labels that are
% specified for each condition should be binned (averaged) to generate new
% trials, or not. This is done by adding 'bin' to the method,
% separated by comma's, like this:
% method = 'linear,bin'; 
% If left out, no binning is applied (default). One can also specify
% 'bintrain' or 'bintest' if binning should only take place on the training
% or on the testing side.
% Other options for method are to specify whether to compute the Scalp
% Current Density (SCD) prior to classification. This is done by either
% specifying 'csd' or 'scd' (e.g. method = 'linear,csd') using the finite
% method from ft_scalpcurrentdensity from the fieldtrip toolbox.
% You can specify the number of times you want to execute a permutation or
% iteration through the create_qsub_files function, by setting the number
% of repeats using settings.repeat as an argument to that function.
% crossclass_and_or_resample specifies whether a cross-classification is
% performed over time, in which each time point is used to classify all
% other time points. This is very time consuming, better set to 0 for first
% analysis, but set to 1 if you want to get a better feel of the data. You
% can speed up cross classification by downsampling the data. This is done
% by specifying the new sampling rate, separating the value for whether or
% not to cross classify from the new sampling rate using a semicolon, like
% this:
% crossclass_and_or_resample = '1;128'; meaning that cross classification
% will be performed and that all data will be resampled to 128 Hz. If no
% value is specified to resample to, the data is left at the original
% sampling rate.
% frequencies allows you to select for which frequencies you want to
% compute classification accuracy. This can be specified as an array, as a
% list of comma separated values, or as a single value. If left empty or
% set to 0, all frequencies are classified.
% varargin is a variable set of conditions to select from, by which each
% main condition is specified as string with comma separated values: 
% cond1 = '1,2,3';
% cond2 = '4,5,6';
% In that setup, all trials containing either a trigger code 1, 2 or 3 will
% be trained and tested as category 1, while all trials containing a 4, 5
% and 6 will be trained and tested as category 2.
% If different condition nrs are used in training versus testing, separate
% the condition specificiation by a semicolon (can only be used when using
% different sets for testing and training):
% cond1 = '1,2;8,9';
% cond2 = '3;10';
% here 1, 2 (the first) would be for training and 8,9 (the second) for
% testing category 1, while 3 would be training category 2 and 10 for
% testing category 2.
% Usage examples:
% TO BE DONE!
%
% J.J.Fahrenfort, VU 2014, 2016

% sanity checking and parameter extraction
warning('off','all')
if isempty(outpath)
    outpath = filepath;
else
    if ~exist(outpath,'dir')
        mkdir(outpath);
    end
end
if ~iscell(filenames)
    filenames = regexp(filenames, ',', 'split');
end
if isempty(nFolds)
    nFolds = 1;
end
if ischar(nFolds)
    nFolds = string2double(nFolds);
end
if ischar(channelset)
    if any(isnan(string2double(channelset)))
        channelset = regexprep(channelset,',','_');
    else
        channelset = str2num(channelset);
    end
end
if isempty(channelset)
    channelset = 1;
end
if isempty(method)
    method = 'linear';
end
if ischar(frequencies)
    frequencies = str2num(frequencies);
end
if isempty(crossclass_and_or_resample)
    crossclass = false;
    resample_eeg = false;
end
if ischar(crossclass_and_or_resample)
    crossclass_and_or_resample = string2double(crossclass_and_or_resample);
end
if numel(crossclass_and_or_resample) > 1
    crossclass = crossclass_and_or_resample(1);
    resample_eeg = crossclass_and_or_resample(2);
else
    crossclass = crossclass_and_or_resample;
    resample_eeg = 0;
end
if ischar(tf_and_erp_baseline) && ~isempty(tf_and_erp_baseline)
    tf_and_erp_baseline = string2double(tf_and_erp_baseline);
    if isempty(tf_and_erp_baseline)
        error('you did not specify the baseline(s) correctly, something went wrong during conversion');
    end
end
if size(tf_and_erp_baseline,1) == 2
   tf_baseline = tf_and_erp_baseline(1,:);
   erp_baseline = tf_and_erp_baseline(2,:);
else
   tf_baseline = tf_and_erp_baseline;
   erp_baseline = tf_and_erp_baseline;
end
if isempty(tf_baseline) || all(tf_baseline==0) || any(isnan(tf_baseline))
    tf_baseline = 'no';
end
if isempty(erp_baseline) || all(erp_baseline==0) || any(isnan(erp_baseline))
    erp_baseline = 'no';
end

% determine condition train-test classes
condSet = [];
if exist('varargin','var') && numel(varargin) > 0 && iscell(varargin)
    if ischar(varargin{1})
        for cCond = 1:numel(varargin)
            condSet{cCond} = string2double(varargin{cCond});
        end
    elseif isnumeric(varargin{1})
        condSet = varargin;
    end
end

% determine settings/methods for analysis
orig_method = method;
setmethod = method;
methods = regexp(method,',','split');
method = 'linear';
measuremethod = 'accuracy';
randomize_labels = false;
iterate = false;
bintest = false;
bintrain = false;
labelsonly = false;
tfr_method = 'total';
do_csd = false;
use_splines = false;
test_total = false;
do_FEM = false;
do_BDM = false;
clean_muscle = false;
clean_window = [];
save_labels = false;
basis_sigma = 1; % default width of basis set if not a delta, if this is empty, do a simple basis set (delta function)
unbalance = false;
detrend_eeg = false;
for c=1:numel(methods)
    if any(strcmpi(methods{c},{'linear', 'quadratic', 'diagLinear', 'diagQuadratic', 'mahalanobis'})) == 1
        method = methods{c};
    end
    if any(strcmpi(methods{c},{'total', 'evoked', 'induced'}))
        tfr_method = methods{c};
    end
    if strcmpi(methods{c},'test_total')
        test_total = true;
    end
    if strcmpi(methods{c},'bin')
        bintrain = true;
        bintest = true;
    end
    if strcmpi(methods{c},'bintrain')
        bintrain = true;
    end
    if strcmpi(methods{c},'bintest')
        bintest = true;
    end
    if strcmpi(methods{c},'randperm')
        randomize_labels = true;
        % create a folder for random permutation
        outpath = [outpath filesep 'randperm'];
        mkdir(outpath);
    end
    if strcmpi(methods{c},'iterate')
        iterate = true;
        % create a folder for iterations
        outpath = [outpath filesep 'iterations'];
        mkdir(outpath);
    end
    if any(strcmpi(methods{c},{'hr-far','dprime','hr','far','mr','cr'}))
        measuremethod = methods{c};
        if numel(condSet) ~= 2
            disp('WARNING: number of stimulus classes is unequal to 2, defaulting back to computing accuracy rather than hr-far');
            measuremethod = 'accuracy'; % defaulting back to accuracy
        else
            disp('computing sdt measure, assuming the first condition is target (signal) and second is non-target (noise)');
        end
    end
    if any(strcmpi(methods{c},{'labelsonly','onlylabels'}))
        labelsonly = true;
        save_labels = true;
        crossclass = false; % cross class is useless when keeping all labels, we will run out of memory (time * time * trials)
        do_FEM = false;
        do_BDM = true;
        disp('Labels only works with BDM only');
    end
    if any(strcmpi(methods{c},{'csd','scd'}))
        do_csd = true;
    end
    if any(strcmpi(methods{c},{'splines','spline'}))
        use_splines = true;
    end
    if any(strcmpi(methods{c},{'FEM','do_FEM','forward'})) && ~labelsonly
        do_FEM = true;
    end
    if any(strcmpi(methods{c},{'BDM','do_BDM','backward'}))
        do_BDM = true;
    end
    if strcmpi(methods{c},'FEM_simple')
        basis_sigma = 0; % the same as setting basis_sigma to 0
    end
    if strncmpi(methods{c},'clean',5)
        clean_muscle = true;
        if numel(methods{c}) > 5
            clean_window = string2double(methods{c}(6:end))';
            if isnan(clean_window)
                clean_window = [];
            end
        end
    end
    if strncmpi(methods{c},'sigma',5)
        if numel(methods{c}) > 5
            basis_sigma = string2double(methods{c}(6:end))';
            if isnan(basis_sigma)
                basis_sigma = 1; % defaulting back to 1
            end
        end
    end
    if any(strcmpi(methods{c},{'save_labels','savelabels'}))
        save_labels = true;
    end
    if any(strcmpi(methods{c},{'unbalance','unbalanced'}))
        unbalance = true;
    end
    if any(strcmpi(methods{c},{'detrend','detrend_eeg'}))
        detrend_eeg = true;
    end
end
if ~do_FEM && ~do_BDM
    do_BDM = true;
end

% check nFolds and condSet
if numel(filenames) > 1 && nFolds > 1
    disp('WARNING: You specified different filenames for training and testing, with more than 1 fold. Leave-one-out is not applicable here. Defaulting nFolds to 1.');
    nFolds = 1; % if you do want to cut up independent sets into folds, you can do so by turning this safety check off
end
if isempty(condSet)
    error('Cannot find usable trigger specification.');
end
% double condset for test and train if only one is specified
if size(condSet{1},1) == 1
    condSet = put_this_condset(condSet,condSet,2);
end
% if using same triggers for training and testing, increase nFolds
if numel(filenames) == 1 && nFolds == 1
    for cCondSet = 1:numel(condSet)
        if any(ismember(condSet{cCondSet}(1,:),condSet{cCondSet}(2,:))) && nFolds == 1
            nFolds = 10;
            wraptext('WARNING: You dirty double dipper! You are using the same data for testing and training without a leave-one-out procedure. Defaulting nFolds to 10 for crossvalidation.',80);
        end
    end
end
% check if condsets are not the same but overlapping, if so unbalance
for cCondSet = 1:numel(condSet)
    if ~all(ismember(condSet{cCondSet}(1,:),condSet{cCondSet}(2,:))) && any(ismember(condSet{cCondSet}(1,:),condSet{cCondSet}(2,:))) && numel(filenames) == 1 && ~unbalance
        unbalance = true;
        wraptext('WARNING: Some stimulus triggers overlap between train and test, overriding balance option');
    end
end

% Pick a name for the channelset (if it is numeric)
if isnumeric(channelset)
    if channelset > 0
        elecSetNames = {'ALL' 'OCCIP' 'PARIET' 'FRONTAL' 'TEMPORAL' 'OCCIPARIET' 'CDA' 'N2Pc_SPCN' };
        channelset = elecSetNames{channelset};
    else
        channelset = 'ALL_NOSELECTION';
    end
end

% create a folder for this electrode group
outpath = [outpath filesep channelset];
if ~exist(outpath,'dir')
    mkdir(outpath);
end

% load data 
for cFile = 1:numel(filenames)
    % NOTE: this line is different in RAW! No resampling done here (yet)...
    [FT_EEG(cFile), filenames{cFile}, chanlocs{cFile}] = read_raw_data(filepath,filenames{cFile},outpath,channelset,erp_baseline,false,do_csd,clean_muscle,clean_window,true,detrend_eeg);
end
 % duplicate data for testing if only one file is available
if numel(filenames) == 1
    FT_EEG(2) = FT_EEG;
end

% extract some relevant trial info, training and testing data
for cSet = 1:2
    thisCondSet = get_this_condset(condSet,cSet);
    % compute ERPs (baseline corrected, resampled, and channels already selected)
    FT_ERP{cSet} = compute_erp_on_FT_EEG(FT_EEG(cSet),thisCondSet,'trial','bin');
    % also compute TFR for entire set
    FT_TFR{cSet} = compute_TFR_from_eeglab('',FT_EEG(cSet),'',resample_eeg,[orig_method ',only_group'],tf_baseline,erp_baseline,frequencies,thisCondSet{:});
    if unbalance
        trialinfo{cSet} = FT_EEG(cSet).trialinfo;
        wraptext('Please realize that triggercodes in a class are now UNBALANCED, such that an unequal distribution of triggercodes is allowed to contribute to each stimulus class. Make sure you know what you are doing, this can have seriously undesirable effects.',80);
    else
        % bin/balance dataset (default action, this is not to achieve actual binnning, it just balances the dataset in case separate conditions still exist in each stimulus class)
        FT_EEG_BINNED(cSet) = compute_bins_on_FT_EEG(FT_EEG(cSet),get_this_condset(condSet,cSet),'trial','original');
        trialinfo{cSet} = FT_EEG_BINNED(cSet).trialinfo;
        oldindex{cSet} = FT_EEG_BINNED(cSet).oldindex;
        wraptext('Please realize that triggercodes in a class are BALANCED by design, such that an equal number of each triggercode goes into each stimulus class. If this is undesirable behavior, specify ''unbalanced'' in your methods.',80);
    end
    % keep track of channels and time line
    channels{cSet} = FT_EEG(cSet).label;
    times{cSet} = FT_EEG(cSet).time;
end

% if testing and training are on different files, check consistency
if numel(filenames) > 1 && ~all(strcmpi(channels{1},channels{2}))
    error('The electrodes do not occur in the same order in testing and training, some coding required to fix this...');
end

% randomize labels if desired. NOTE: permuting all labels of the input set,
% regardless of whether there is a separate testing set or not
if randomize_labels
    trialinfo{1} = trialinfo{1}(randperm(numel(trialinfo{1})));
end

% Generate indices for folds to do training and testing
[setindex{1}, setindex{2}, nFolds] = make_folds(trialinfo{1},trialinfo{2},condSet,nFolds,labelsonly);

% create file name based on actual folds and save ERPs and TFRs
if numel(filenames) == 1
    filename = ['CLASS_PERF_' filenames{1} '_' num2str(nFolds) 'fold'];
else
    filename = ['CLASS_PERF_' filenames{1} '_' filenames{2}];
end
if ~crossclass 
    mkdir([outpath filesep 'allfreqs']);
    if ~(randomize_labels || iterate)
        fullfilename = [ outpath filesep 'allfreqs' filesep filename ];
        save(fullfilename, 'FT_ERP', 'FT_TFR', '-v7.3'); 
    end
end
clear FT_EEG_BINNED FT_ERP FT_TFR; % save memory by clearing

% unpack setindex{1} and setindex{2} to get back the original index numbers
if ~unbalance
    [setindex{1}, setindex{2}] = unpack_binned(setindex{1}, setindex{2}, oldindex{1}, oldindex{2});
end

% create and save TFR for training and testing
% do trial selection prior to TFR computation (important for induced!)
for cFld = 1:nFolds
    for cSet = 1:2
        % FYI
        set_tfr_method{cSet} = tfr_method;
        % select trials belonging to this subset
        trialindex = vertcat(setindex{cSet}{cFld,:});
        % keep trying if running into memory issues (often temporary because all analyses are running in parallel)
        success = false; counterr = 0;
        while ~success
            try
                FT_EEG_2use = select_trials_from_FT_EEG(FT_EEG(cSet),trialindex);
                success = true;
            catch ME
                disp(ME); disp('Memory problem? Let''s wait a bit before trying again.'); counterr = counterr + 1; if counterr > 10; error('errrrr, tried 10 times, giving up now...'); end; pause(600); 
            end
        end
        method_2use = orig_method;
        % FYI
        set_use_splines(cFld,cSet) = use_splines;
        % if test_total is true, refrain from using induced during test,
        % otherwise check trial numbers, if too few subtract splines rather
        % than average ERP (default)
        if strcmpi(tfr_method,'induced') && cSet == 2 && test_total
            disp('Using total power instead of induced power for testing, useful when there are too few trials in test to compute quality ERPs.');
            method_2use = strrep(orig_method,'induced','total');
            set_tfr_method{cSet} = 'total'; % FYI
        elseif strcmpi(tfr_method,'induced') && numel(trialindex) < (25*numel(condSet)) % default action if there are not enough trials in test
            disp('WARNING: fewer than 25 trials to compute an ERP for subtraction in induced power, computing spline on ERP before subtraction to be safe.');
            method_2use = [orig_method ',splines'];
            set_use_splines(cFld,cSet) = true; % FYI
        end
        % get relevant condSet for TFR computation
        condSet_2use = get_this_condset(condSet,cSet);
        % compute time frequency power spectrum and save result for each fold
        % keep trying if running into memory issues (often temporary)
        success = false; counterr = 0;
        while ~success
            try
                fnames{cFld,cSet} = compute_TFR_from_eeglab('',FT_EEG_2use,[filepath filesep '..' ],resample_eeg,method_2use,tf_baseline,erp_baseline,frequencies,condSet_2use{:});
                success = true;
            catch ME
                disp(ME); disp('Memory problem? Let''s wait a bit before trying again.'); counterr = counterr + 1; if counterr > 10; error('errrrr, tried 10 times, giving up now...'); end; pause(600); 
            end
        end
        clear FT_EEG_2use; % clear the dataset so we don't need it in memory during analyses
        % wait for file to complete writing, seems to work
        while ~exist([fnames{cFld,cSet} '.mat'],'file')
        end
        filesize = 0; sizenow = 1000;
        while filesize ~= sizenow
            info = dir([fnames{cFld,cSet} '.mat']);
            filesize = info.bytes;
            disp(['file is ' num2str(filesize) ' bytes...']);
            pause(.5);
            info = dir([fnames{cFld,cSet} '.mat']);
            sizenow = info.bytes;
        end
        % just FYI, how big are the temporary files
        filesizes_MB(cFld,cSet) = round(sizenow/(2^20)*100)/100;
    end
end % end folds loop in which temp files are created
clear FT_EEG; % clear the dataset so we don't need it in memory during analyses

% create file pointer and extract some relevant info from the first two
% files for sanity checks
[~, actualfrequencies, times{1}, trialinfo{1}, chanindex] = read_mat_file(fnames{1,1},channels{1});
actualfrequencies = round(actualfrequencies*100)/100;

% if testing and training are on different data, load info of second set
if numel(filenames) > 1
    [~, actualfrequencies2, times{2}, trialinfo{2}, chanindex2] = read_mat_file(fnames{1,2},channels{2});
    actualfrequencies2 = round(actualfrequencies2*100)/100;
    if ~all(actualfrequencies==actualfrequencies2)
        disp('WARNING: there seems to be a mismatch in both datasets, they do not seem to contain the same frequencies.');
        disp(['dataset 1, ' filenames{1} ': ' num2str(actualfrequencies)]);
        disp(['dataset 2, ' filenames{2} ': ' num2str(actualfrequencies2)]);
    end
    if ~all(chanindex==chanindex2)
        error('the (same) electrodes do not occur (in the same order) in testing and training, some coding required to fix this...');
    end
end

% if no frequencies are specified, or if this is not a crossclassification, compute all frequencies
if isempty(frequencies) || sum(frequencies) == 0 || ~crossclass
    frequencies = actualfrequencies;
else
    frequencies = round(frequencies*100)/100;
end

% now loop over frequencies
for cFreq = 1:numel(frequencies)
          
    % Run classification
    clear BDM_* FEM_*;
    settrialinfo = [];
    for cFld=1:nFolds
        % create file pointers for this fold
        [matObj, ~, times{1}, trialinfo{1}, chanindex, chandim, timedim, trialdim, freqdim ] = read_mat_file(fnames{cFld,1},channels{1});
        [matObj2, ~, times{2}, trialinfo{2}, chanindex2, chandim2, timedim2, trialdim2, freqdim2 ] = read_mat_file(fnames{cFld,2},channels{2});
        % read in data, only relevant frequency (dimension is dynamic)
        frequency = frequencies(cFreq);
        index    = cell(1,4);
        index(:) = {':'};
        index{freqdim} = find(frequency==actualfrequencies);
        if isempty(index{freqdim})
            disp('WARNING: cannot find an exact match for that frequency, attempting to find the closest match');
            index{freqdim} = nearest(actualfrequencies,frequency);
            if isempty(index{freqdim})
                error(['error, cannot find a matching frequency for frequency ' num2str(frequency) ', giving up now']);
            end
        end
        % FYI
        fprintf(1,['fold: ' num2str(cFld) ', frequency: ' num2str(frequency) '\n']);       
        % load data, alldata = elec * time * trial, remove obsolete electrodes
        alldata{1} = matObj.powspctrm(index{:});
        alldata{1} = permute(alldata{1},[chandim timedim trialdim freqdim]); % should be  elec * time * trial, also remove channels
        alldata{1} = alldata{1}(chanindex,:,:); 
        labels{1} = make_group_labels(trialinfo{1}, get_this_condset(condSet,1));
        alldata{2} = matObj2.powspctrm(index{:});
        alldata{2} = permute(alldata{2},[chandim2 timedim2 trialdim2 freqdim2]); % should be channel x time x trial, also remove irrelevant channels
        alldata{2} = alldata{2}(chanindex2,:,:);
        labels{2} = make_group_labels(trialinfo{2}, get_this_condset(condSet,2));
        % settings for backward and/or forward modelling
        msettings.crossclass = crossclass;
        msettings.method = method;
        msettings.labelsonly = labelsonly;
        msettings.doBDM = do_BDM;
        msettings.doFEM = do_FEM;
        msettings.basis_sigma = basis_sigma;
        % run analysis, clear memory afterwards
        % note that Matlab does not copy a matrix that is passed into a  function when that matrix 
        % is not modified inside that function. Rather, it creates a pointer to save memory :-)
        [BDM, FEM] = EEG_backward_and_forward_matrix(alldata{2},alldata{1},labels{2},labels{1},msettings);
        % clear obsolete data 
        clear alldata labels;
        % some BDM and FEM specific stuff
        if do_BDM
            if save_labels
                BDM_labelMatrixOverT(cFld,:,:,:,:) = BDM.LabelsOverTime; % fld x t1 x t2 x response_matrix OR fld x trial x t1 (assigned_labels when method = 'labelsonly')
            end
            if labelsonly
                BDM_ClassOverT(cFld) = NaN;
            else
                BDM_ClassOverT(cFld,:,:) = class_accuracy_from_matrix(BDM.LabelsOverTime,measuremethod,crossclass); % fld x t1 x t2
            end
            BDM_WeightsOverT(cFld,:,:) = BDM.WeightsOverTime; % fld x time x elec
            BDM_covPatternsOverT(cFld,:,:) = BDM.covPatternsOverTime; % fld x time x elec
            BDM_corPatternsOverT(cFld,:,:) = BDM.corPatternsOverTime; % fld x time x elec
        end
        if do_FEM
            if save_labels
                FEM_labelMatrixOverT(cFld,:,:,:,:) = FEM.LabelsOverTime;
            end
            % FEM_ClassOverT(cFld,:,:) = class_accuracy_from_matrix(FEM.LabelsOverTime,measuremethod); % fld x t1 x t2
            FEM_ClassOverT(cFld,:,:) = tuning_from_matrix(FEM.C2_average,'slope',crossclass); % fld x t1 x t2
            FEM_WeightsOverT(cFld,:,:,:) = FEM.WeightsOverTime; % fld x time x elec x channel_response
            FEM_C2_average(cFld,:,:,:) = FEM.C2_average; % fld x time x time x channel_response
            FEM_C2_percondition(cFld,:,:,:,:) = FEM.C2_percondition; % fld x time x time x cond x channel_response
        end
        % FYI
        settrialinfo = [settrialinfo; trialinfo];
        
    end % end folds loop, only frequency loop is left
    
    % mean data, average over folds where applicable
    BDM = [];
    FEM = [];
    BDMLabelsOverTime = [];
    FEMLabelsOverTime = [];
    if do_BDM
        BDM.ClassOverTime = squeeze(mean(BDM_ClassOverT,1)); % t1 x t2 or trial x t1
        BDM.WeightsOverTime = squeeze(mean(BDM_WeightsOverT,1)); % time x elec x channel_response
        BDM.covPatternsOverTime = squeeze(mean(BDM_covPatternsOverT,1)); % time x elec
        BDM.corPatternsOverTime = squeeze(mean(BDM_corPatternsOverT,1)); % time x elec
        if save_labels
            BDMLabelsOverTime = squeeze(BDM_labelMatrixOverT); % fld x t1 x t2 x response_matrix OR fold x trial x t1 (assigned_labels when method = 'labelsonly')
        end
        clear BDM_*;
    end
    if do_FEM
        FEM.ClassOverTime = squeeze(mean(FEM_ClassOverT,1));
        FEM.WeightsOverTime = squeeze(mean(FEM_WeightsOverT,1));
        FEM.C2_average = squeeze(mean(FEM_C2_average,1));
        FEM.C2_percondition = squeeze(mean(FEM_C2_percondition,1));
        if save_labels
            FEMLabelsOverTime = squeeze(FEM_labelMatrixOverT);
        end
        clear FEM_*;
    end
    
    % save some settings so we know wtf just happened
    settings.nconds = numel(condSet);
    settings.nfolds = nFolds;
    settings.filenames = filenames;
    settings.crossclass = crossclass;
    settings.erp_baseline = erp_baseline;
    settings.tf_baseline = tf_baseline;
    settings.clean_window = clean_window;
    settings.detrend_eeg = detrend_eeg;
    settings.BDM = do_BDM;
    settings.FEM = do_FEM;
    settings.basis_set_sigma = basis_sigma;
    settings.method_string = setmethod;
    settings.tfr_method = set_tfr_method;
    settings.use_splines_for_erps = set_use_splines; % when induced this means it subtracted the splined erps, when evoked it this means it used the splines of the erps
    settings.channelset = channelset;
    settings.channels = channels;
    settings.chanlocs = chanlocs;
    settings.times = times;
    settings.measuremethod = measuremethod;
    settings.trialinfo = settrialinfo;
    settings.setindex = setindex;
    settings.condset = condSet;
    settings.csd_transform = do_csd;
    settings.bintrain = bintrain;
    settings.bintest = bintest;
    settings.unbalance = unbalance;
    settings.filesizes_MB = filesizes_MB;
    
    % if crossclass is true, save crossclassification result PER FREQUENCY
    if crossclass
        settings.frequency = frequency;
        settings.dimord = 'time_time';
        mkdir([outpath filesep 'freq' num2str(frequency)]);
        % count filenames from 001 onwards if computing under random permutation or iteration
        if randomize_labels || iterate
            fullfilename = find_filename([outpath filesep 'freq' num2str(frequency)],filename);
        else
            fullfilename = [ outpath filesep 'freq' num2str(frequency) filesep filename ];
        end
        save(fullfilename, 'FEM', 'BDM', 'settings', '-v7.3');
        if save_labels
            if labelsonly
                save_var_under_different_name(fullfilename,BDMLabelsOverTime, 'BDM_LabelsOverTime', FEMLabelsOverTime, 'FEM_LabelsOverTime');
            else
                save_var_under_different_name(fullfilename,BDMLabelsOverTime, 'BDM_ConfusionMatrixOverTime', FEMLabelsOverTime, 'FEM_ConfusionMatrixOverTime')
            end
        end
    else
        % get only diagonals for frequency in case crossclass is false
        if do_BDM
            if labelsonly % only the assigned labels
                BDMfreq_ClassOverTime = NaN;
                BDMfreq_LabelsOverTime(:,:,cFreq,:) = squeeze(BDMLabelsOverTime); % fold x trial x freq x t1 (assigned_labels when method = 'labelsonly')
            else 
                BDMfreq_ClassOverTime(cFreq,:) = diag(BDM.ClassOverTime); % result is freq x time
                if save_labels
                    for cTime=1:size(BDMfreq_ClassOverTime,2) % more complex when considering the response matrix, can't use diag:  LabelsOverTime is fold x t1 x t2 x response_matrix
                        BDMfreq_LabelsOverTime(:,cFreq,cTime,:,:) = squeeze(BDMLabelsOverTime(:,cTime,cTime,:,:)); % fold x t1 x t2 x response_matrix
                    end
                end
            end
            BDMfreq_WeightsOverTime(cFreq,:,:) = BDM.WeightsOverTime; % result is freq x time x chan
            BDMfreq_covPatternsOverTime(cFreq,:,:) = BDM.covPatternsOverTime; % result is freq x time x chan
            BDMfreq_corPatternsOverTime(cFreq,:,:) = BDM.corPatternsOverTime; % result is freq x time x chan
        end
        if do_FEM
            FEMfreq_ClassOverTime(cFreq,:) = diag(FEM.ClassOverTime);
            FEMfreq_WeightsOverTime(cFreq,:,:,:) = FEM.WeightsOverTime;
            for cTime=1:size(FEMfreq_ClassOverTime,2) % slightly more complex, can't use diag
                FEMfreq_C2_percondition(cFreq,cTime,:,:) = squeeze(FEM.C2_percondition(cTime,cTime,:,:));
                FEMfreq_C2_average(cFreq,cTime,:) = squeeze(FEM.C2_average(cTime,cTime,:));
                if save_labels
                    FEMfreq_LabelsOverTime(:,cFreq,cTime,:,:) = squeeze(FEMLabelsOverTime(:,cTime,cTime,:,:)); % fold x t1 x t2 x response_matrix
                end
            end
        end
    end % endif crossclass conditional
    
end % end frequency loop

% all frequencies done, delete obsolete files
for cFld = 1:nFolds
    for cSet = 1:2
        delete([fnames{cFld,cSet} '.mat']);
    end
end

% if crossclass is false, save decoding accuracy for all frequencies
if ~crossclass
    BDM = [];
    FEM = [];
    BDMLabelsOverTime = [];
    FEMLabelsOverTime = [];
    if do_BDM
        BDM.ClassOverTime = BDMfreq_ClassOverTime;
        BDM.WeightsOverTime = BDMfreq_WeightsOverTime;
        BDM.covPatternsOverTime = BDMfreq_covPatternsOverTime;
        BDM.corPatternsOverTime = BDMfreq_corPatternsOverTime;
        if save_labels
            BDMLabelsOverTime = BDMfreq_LabelsOverTime;
        end
        clear BDMfreq_*;
    end
    if do_FEM
        FEM.ClassOverTime = FEMfreq_ClassOverTime;
        FEM.WeightsOverTime = FEMfreq_WeightsOverTime;
        FEM.C2_percondition = FEMfreq_C2_percondition;
        FEM.C2_average = FEMfreq_C2_average;
        if save_labels
            FEMLabelsOverTime = FEMfreq_LabelsOverTime;
        end
        clear FEMfreq_*;
    end
    settings.freqs = frequencies;
    settings.dimord = 'freq_time';
    % count filenames from 001 onwards if computing under permutation or iteration
    if randomize_labels || iterate
        fullfilename = find_filename([outpath filesep 'allfreqs'],filename);
        save(fullfilename, 'FEM', 'BDM', 'settings', '-v7.3');
    else
        fullfilename = [ outpath filesep 'allfreqs' filesep filename ];
        save(fullfilename, 'FEM', 'BDM', 'settings', '-v7.3', '-append'); % this file also contains the ERPs and the TFRs, so append
    end
    if save_labels
        if labelsonly
            save_var_under_different_name(fullfilename,BDMLabelsOverTime, 'BDM_LabelsOverTime', FEMLabelsOverTime, 'FEM_LabelsOverTime');
        else
            save_var_under_different_name(fullfilename,BDMLabelsOverTime, 'BDM_ConfusionMatrixOverTime', FEMLabelsOverTime, 'FEM_ConfusionMatrixOverTime');
        end
    end
end

% turn warnings back on
warning('on','all')

function fullfile = find_filename(path,filename)
c = 1;
fullfile = sprintf([path filesep filename '_PERM%03d'], c);
while numel(dir([fullfile '.*']))>0
    c = c + 1;
    fullfile = sprintf([path filesep filename '_PERM%03d'], c);
end
