function map = plot_MVPA(stats,cfg)
% function plotMVPA(stats,cfg)
% draw classification accuracy based on stats produced by
% compute_group_MVPA
%
% By J.J.Fahrenfort, VU, 2014, 2015, 2016, 2017
if nargin<2
    disp('cannot plot graph without some settings, need at least 2 arguments:');
    help plotMVPA;
    return
end
ndec = 2;
plotsubject = false;
singleplot = false;
plot_order = [];
folder = '';
startdir = '';
if numel(stats) > 1
    line_colors = {[.5 0 0], [0 .5 0] [0 0 .5] [.5 .5 0] [0 .5 .5] [.5 0 .5]};
else
    line_colors = {[0 0 0]};
end
v2struct(cfg);
cfg.singleplot = singleplot;
if any(size(stats(1).ClassOverTime)==1)
    plottype = '2D'; %  used internally in this function
else
    plottype = '3D';
end
cfg.plottype = plottype;
if strcmpi(plottype,'3D')
    singleplot = false;
    cfg.singleplot = singleplot;
end
if numel(line_colors)<numel(stats) || isempty(line_colors)
    if numel(stats) > 1
        line_colors = {[.5 0 0], [0 .5 0] [0 0 .5] [.5 .5 0] [0 .5 .5] [.5 0 .5]};
    else
        line_colors = {[0 0 0]};
    end
end

cfg.line_colors = line_colors;
cfg.ndec = ndec; % number of decimals used when plotting accuracy tick labels

% main routine, either plot only one or all conditions
if ~plotsubject
    title_text = regexprep(regexprep(folder,startdir,''),'_',' ');
    title_text = title_text(1:find(title_text==filesep,1,'last')-1);
    fh = figure('name',title_text);
    % make sure all figures have the same size regardless of nr of subplots
    UL=[600 450];
    po=get(fh,'position');
    % the line below needs to be adjusted for singleplot
    if singleplot
        po(3:4)=UL;
    else
        po(3:4)=UL.*[numSubplots(numel(stats),2) numSubplots(numel(stats),1)];
    end
    set(fh,'position',po);
    set(fh,'color','w');
end
if numel(stats)>1
    % main loop for each condition
    for cStats=1:numel(stats)
        if ~isempty(plot_order)
            suborder = find(strcmpi(stats(cStats).condname,cfg.plot_order),1);
            if isempty(suborder) 
                error('cannot find condition name specified in cfg.plot_order');
            end
        else
            suborder = cStats;
        end
        disp(['plot ' num2str(suborder)]);
        if singleplot
            hold on;
            [map, H] = subplot_MVPA(stats(cStats),cfg,suborder);
            legend_handle(suborder) = H.mainLine;
            legend_text{suborder} = regexprep(stats(cStats).condname,'_',' ');
        else
            subplot(numSubplots(numel(stats),1),numSubplots(numel(stats),2),suborder);
            map = subplot_MVPA(stats(cStats),cfg,suborder); % all in the first color
            title(regexprep(stats(cStats).condname,'_',' '));
        end
    end
    if singleplot
        legend(legend_handle,legend_text);
        legend boxoff;
    end
else
    map = subplot_MVPA(stats,cfg);
end

function [map, H] = subplot_MVPA(stats,cfg,cGraph)
map = [];
if nargin<3
    cGraph = 1;
end

% setting some graph defaults
nconds = stats.settings.nconds;
plotsubject = false;
trainlim = [];
testlim = [];
freqlim = [];
acclim3D = [];
acclim2D = [];
freqtick = [];
plot_model = [];
reduce_dims = [];
inverty = false;
downsamplefactor = 1;
cent_acctick = 1/nconds;
smoothfactor = 1;
plotsigline_method = 'both';
splinefreq = [];
timetick = 250;
acctick = .05;
mpcompcor_method = 'uncorrected';
plotsubjects = false;
cluster_pval = .05;
indiv_pval = .05;
one_two_tailed = 'two';

% then unpack cfgs to overwrite defaults, first original from stats, then the new one 
if isfield(stats,'cfg')
    oldcfg = stats.cfg;
    v2struct(oldcfg); % unpack the stats-specific cfg
end
v2struct(cfg);
if isempty(splinefreq)
    makespline = false;
else
    makespline = true;
end

% unpack stats
v2struct(stats);
settings = stats.settings; % little hardcoded hack because settings.m is apparently also a function

% now settings should be here, unpack these too
freqs = 0;
v2struct(settings);

% fill some empties
if isempty(freqtick)
    if max(freqlim) >= 60
        freqtick = 20;
    else
        freqtick = 10;
    end
end
if isempty(acctick)
    acctick = .05;
end
eval(['acclim = acclim' plottype ';']);

% if time tick is smaller than sample duration, increase time tick to sample duration
if numel(times{1})>1 && timetick < (times{1}(2)-times{1}(1))*1000
    timetick = ceil((times{1}(2)-times{1}(1))*1000);
end

% get x-axis and y-axis values
[dims] = regexp(dimord, '_', 'split');
ydim = dims{1};
xdim = dims{2}; % unused

% first a hack to change make sure that whatever is in time is expressed as ms
if mean(times{1}<10)
    times{1} = round(times{1} * 1000);
    if numel(times) > 1
        times{2} = round(times{2} * 1000);
    end
end

% set color-limits (z-axis) or y-limits
if strcmpi(measuremethod,'hr-far') || strcmpi(plot_model,'FEM')
    chance = 0;
    cent_acctick = 0;
else
    chance = cent_acctick;
end
if isempty(acclim)
    mx = max(max((ClassOverTime(:)-chance)));
    if strcmpi(plottype,'2D') % this is a 2D plot
        shift = mx/20;
        acclim = [chance-shift mx+chance+shift];
    else
        acclim = [-mx mx] + chance;
    end
end
if numel(acclim) == 1
    acclim = [-acclim acclim];
end
acclim = sort(acclim);

% determine axes
if strcmpi(reduce_dims,'avtrain') 
    xaxis = times{2};
elseif strcmpi(reduce_dims,'avtest') || strcmpi(reduce_dims,'avfreq')
    xaxis = times{1};
elseif strcmpi(dimord,'time_time')
    xaxis = times{1};
    yaxis = times{2};
elseif strcmpi(dimord,'freq_time')
    xaxis = times{1};
    yaxis=round(freqs);
end

% stuff particular to 2D and 3D plotting
if strcmpi(plottype,'2D')
    yaxis = sort(unique([cent_acctick:-acctick:min(acclim) cent_acctick:acctick:max(acclim)]));
    data = ClassOverTime;
    stdData = StdError;
    % some downsampling on 2D
    if ~isempty(downsamplefactor) && downsamplefactor > 0
        xaxis = downsample(xaxis,downsamplefactor);
        data = downsample(data,downsamplefactor);
        if ~isempty(StdError)
            stdData = downsample(stdData,downsamplefactor);
        end
        if ~isempty(pVals)
            pVals = downsample(pVals,downsamplefactor);
        end
    end
    % some smoothing on 2D using spline
    if makespline
       data = compute_spline_on_classify(data,xaxis',splinefreq);
       stdData = compute_spline_on_classify(stdData,xaxis',splinefreq);
    end
else
    zaxis = sort(unique([cent_acctick:-acctick:min(acclim) cent_acctick:acctick:max(acclim)]));
    data = ClassOverTime;
end

% set ticks for x-axis and y-axis
xticks = timetick;
if strcmpi(plottype,'3D')
    if strcmpi(ydim,'freq')
        yticks = freqtick;
    else
        yticks = xticks;
    end
else
    yticks = acctick;
end

% some smoothing on 3D, this may neeed fixing?
if makespline && strcmpi(plottype,'3D')
    xaxis = spline(1:numel(xaxis),xaxis,linspace(1, numel(xaxis), round(numel(xaxis)/smoothfactor))); 
    yaxis = spline(1:numel(yaxis),yaxis,linspace(1, numel(yaxis), round(numel(yaxis)/smoothfactor))); 
end

% make a timeline that has 0 as zero-point and makes steps of xticks
if min(xaxis) < 0 && max(xaxis) > 0
    findticks = sort(unique([0:-xticks:min(xaxis) 0:xticks:max(xaxis)]));
else
    findticks = sort(unique(min(xaxis):xticks:max(xaxis)));
end
indx = [];
for tick = findticks
    indx = [indx nearest(xaxis,tick)];        
end

% do the same for y-axis
if strcmpi(ydim,'freq')
    findticks = yticks:yticks:max(yaxis);
else
    if min(yaxis) < 0 && max(yaxis) > 0
        findticks = sort(unique([0:-yticks:min(yaxis) 0:yticks:max(yaxis)]));
    else
        findticks = sort(unique(min(yaxis):yticks:max(yaxis)));
    end
end
indy = [];
for tick = findticks
    indy = [indy nearest(yaxis,tick)];
end

% plot
if strcmpi(plottype,'2D')
    colormap('default');
    if isempty(StdError)
        H.dataLine = plot(data);
    else
        H = shadedErrorBar(1:numel(data),data,stdData,{'Color',[.7,.7,.7],'MarkerFaceColor',[1 1 0]},.5); % [1 1 0] {'MarkerFaceColor',[.7,.7,.7]}
    end
    hold on;
    % plot horizontal line on zero
    plot([1,numel(data)],[chance,chance],'k--');
    % plot vertical line on zero
    plot([nearest(xaxis,0),nearest(xaxis,0)],[acclim(1),acclim(2)],'k--');
    % plot another help line
    % plot([nearest(xaxis,250),nearest(xaxis,250)],[acclim(1),acclim(2)],'k--');
    % plot significant time points
    if ~isempty(pVals)
        sigdata = data;
        if strcmpi(plotsigline_method,'straight') || strcmpi(plotsigline_method,'both') && ~plotsubject && ~strcmpi(mpcompcor_method,'none')
            if ~singleplot elevate = 1; else elevate = cGraph; end
            if inverty
                sigdata(1:numel(sigdata)) = max(acclim) - (diff(acclim)/100)*elevate;
            else
                sigdata(1:numel(sigdata)) = min(acclim) + (diff(acclim)/100)*elevate;
            end
            sigdata(pVals>=indiv_pval) = NaN;
            if isnumeric(line_colors{cGraph})
                H.bottomLine=plot(1:numel(sigdata),sigdata,'Color',line_colors{cGraph},'LineWidth',2); % sigline below graph
            else
                H.bottomLine=plot(1:numel(sigdata),sigdata,line_colors{cGraph},'LineWidth',2); % sigline below graph
            end
        end
        sigdata = data;
        if ~strcmpi(plotsigline_method,'straight')
            sigdata(pVals>=indiv_pval) = NaN;
            if isnumeric(line_colors{cGraph})
                H.mainLine=plot(1:numel(sigdata),sigdata,'Color',line_colors{cGraph},'LineWidth',2); % sigline on graph
            else
                H.mainLine=plot(1:numel(sigdata),sigdata,line_colors{cGraph},'LineWidth',2); % sigline on graph
            end
        end
        if ~all(isnan((sigdata)))
            wraptext('Due to a bug in the way Matlab exports figures (the ''endcaps'' property in OpenGL is set to''on'' by default), the ''significance lines'' near the time line are not correctly plotted when saving as .eps or .pdf. The workaround is to open these plots in Illustrator, manually select these lines and select ''butt cap'' for these lines (under the ''stroke'' property).');
        end
        if strcmpi(one_two_tailed,'one') one_two_tailed = '1'; else  one_two_tailed = '2'; end
        if ~plotsubject
            if strcmpi(mpcompcor_method,'uncorrected')
                h_legend = legend(H.mainLine,[' p < ' num2str(indiv_pval) ' (uncorrected, ' one_two_tailed '-sided)']); % ,'Location','SouthEast'
            elseif strcmpi(mpcompcor_method,'cluster_based')
                h_legend = legend(H.mainLine,[' p < ' num2str(cluster_pval) ' (cluster based, ' one_two_tailed '-sided)']);
            elseif strcmpi(mpcompcor_method,'fdr')
                h_legend = legend(H.mainLine,[' p < ' num2str(cluster_pval) ' (FDR, ' one_two_tailed '-sided)']);
            end
        end
        legend boxoff;
        %set(h_legend,'FontSize',14);
    end
    ylim(acclim);
    % little hack
    if strcmpi(plot_model,'FEM')
        measuremethod = 'CTF slope';
    end
    ylabel(measuremethod);
    set(gca,'YTick',yaxis);
    if cent_acctick ~= 0 % create labels containing equal character counts when centered on some non-zero value
        Ylabel = strsplit(deblank(sprintf(['%0.' num2str(ndec) 'f '],yaxis)),' ');
        Ylabel((yaxis == chance)) = {'chance'}; % say "chance".
        set(gca,'YTickLabel',Ylabel);
    end
    hold off;
else
    % plot significant time points
    %colormap('jet');
    cmap  = brewermap([],'RdBu');
    colormap(cmap(end:-1:1,:)); 
    
    if ~isempty(pVals) && ~strcmpi(mpcompcor_method,'none')
        [data, map] = showstatsTFR(data,pVals,acclim);
    end
    % some smoothing on 3D
    if makespline
        if ndims(data) > 2 % DOUBLE CHECK WHETHER THIS IS OK
            [X,Y,Z] = meshgrid(1:size(data,2),1:size(data,1),1:size(data,3));
            [XX,YY,ZZ] = meshgrid(linspace(1,size(data,2),round(size(data,2)/smoothfactor)),linspace(1,size(data,1),round(size(data,1)/smoothfactor)),1:size(data,3));
            data = interp3(X,Y,Z,data,XX,YY,ZZ);
        else
            % this cannot happen because we are in 3D plotting part right?
            [X,Y] = meshgrid(1:size(data,2),1:size(data,1));
            [XX,YY] = meshgrid(linspace(1,size(data,2),round(size(data,2)/smoothfactor)),linspace(1,size(data,1),round(size(data,1)/smoothfactor)));
            data = uint8(interp2(X,Y,double(data),XX,YY));
        end
    end
    imagesc(data);
    caxis(acclim);
    set(gca,'YDir','normal'); % set the y-axis right
    if ~plotsubject
        hcb=colorbar;
    end
    % set ticks on color bar
    if ~plotsubject
        set(hcb,'YTick',zaxis);
        if cent_acctick ~= 0 % create labels containing equal character counts when centered on some non-zero value
            Ylabel = strsplit(deblank(sprintf(['%0.' num2str(ndec) 'f '],zaxis)),' ');
            Ylabel((zaxis == chance)) = {'chance'}; % say "chance".
            set(hcb,'YTickLabel',Ylabel);
        end
    end
    if strcmpi(ydim,'freq')
        ylabel('frequency in Hz');
        xlabel('time in ms');
    else
        ylabel('testing time in ms');
        xlabel('training time in ms');
    end
    set(gca,'YTick',indy);
    roundto = yticks;
    set(gca,'YTickLabel',num2cell(round(yaxis(indy)/roundto)*roundto));
end
% set ticks on horizontal axis
set(gca,'XTick',indx);
roundto = xticks;
set(gca,'XTickLabel',num2cell(round(xaxis(indx)/roundto)*roundto));
if plotsubject
    set(gca,'FontSize',10);
else
    set(gca,'FontSize',16);
end
set(gca,'color','none');
axis square;
if inverty
    set(gca,'YDir','reverse');
end
if (isempty(acclim2D) && strcmpi(plottype,'2D')) || (isempty(acclim3D) && strcmpi(plottype,'3D')) 
    sameaxes('xyzc',gcf());
end
% invent handle if it does not exist
if ~exist('H')
    H = [];
end