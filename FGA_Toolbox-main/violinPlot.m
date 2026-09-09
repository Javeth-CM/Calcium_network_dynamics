function varargout = violinPlot(varX, varG, varB, varargin)
%VIOLINPLOT - Extended function for boxplots
% Inputs arguments:
%	varX: Input data, specified as a 1-by-m array.
%	varG: Grouping variable, specified as a 1-by-m categorical array.
%	varB: Random effect variable, specified as a 1-by-m categorical array.
%	      For example, this array can contain labels for different biological replicas.
%
% Name Only Arguments      
%	'dots': Add individual datapoints to the plot
%	'bar': Create a barplot instead of a boxplot (default)
%	'Notch': Add the data notch to the boxplot
%	'SameFigure': Plot the data in the current selected axis
%	'Median': Use the median as normalization method, default is mean
%	          Note that this options requires the 'Normalize' argument.
%	'BeforeAfter': Plot the data connecting ech dots in pairs.
%	               Note that this options requires the 'SecondCondition' argument.
%	'FlipAxis': Rotate the plot to that the X and Y axis are swapped.
%	'InvertCondition': Use to quickly swap conditions.
%	                   Note that this options requires the 'SecondCondition' argument.
%
% Name-Value Pair Arguments
%	'Color' - RGB Triplet: User designed colormap. The default is "colorcube".
%	'Label' - text: Text to use to label the Y-axis.
%	'Axes' - Axes handle: Declear which axes to plot.
%	'Normalize' - text: The name of the condition where the data should be normalized against.
%	                    For 0-1 normalization, indicate both names into a cell array.
%	'SecondCondition' - array: Additional grouping variable, specidied as a 1-by-m categorical array
%
% Examples
% Create the syntetic data
% varX = [rand(10,1)*0.5;rand(10,1)*0.5;rand(10,1)*0.5;rand(10,1)*2.5;rand(10,1)*2.5;rand(10,1)*2.5];
% varG = categorical(repelem({'Group1'; 'Group2'}, 30, 1));
% varX = categorical(repelem([1;2;3;1;2;3], 10, 1));
%
% Simple use
% violinPlot(varX, varG, varB);
%
% Add dots to the plot
% violinPlot(varX, varG, varB, 'dots');
%
% Normalize the data
% violinPlot(varX, varG, varB, 'dots', 'Normalize', 'Group1');
%
% Add a second condition
% varS = categorical(repelem({'Cat1';'Cat2';'Cat1';'Cat2'},15,1));
% violinPlot(varX, varG, varB, 'dots', 'SecondCondition', varS);
% violinPlot(varX, varG, varB, 'dots', 'SecondCondition', varS, 'BeforeAfter');
%
% See also: PLOT,  BOXPLOT, PATCH

% Author: Alessandro Moro
% Dept. Functional Genomics,
% Center for Neurogenomics and Cognitive Research (CNCR),
% email: a.moro@vu.nl

bDots = any(strcmpi(varargin, 'dots'));
bNormal = any(strcmpi(varargin, 'normalize'));
bBar = any(strcmpi(varargin, 'bar'));
bViolin = any(strcmpi(varargin, 'violin'));
bLabel = any(strcmpi(varargin, 'label'));
bColor = any(strcmpi(varargin, 'color'));
bFlip = any(strcmpi(varargin, 'flipAxis'));
bExperiment = any(strcmpi(varargin, 'experiment')); % if the table is a collection of multiple experiments
bSecond = any(strcmpi(varargin, 'secondCondition'));
bInvert = any(strcmpi(varargin, 'invertCondition'));
bSame = any(strcmpi(varargin, 'sameFigure'));
beforeAfter = any(strcmpi(varargin, 'beforeAfter'));
bMedian = any(strcmpi(varargin, 'median')); % normalization method, default is mean
bAxes = any(strcmpi(varargin, 'axes')); % declear which axes to plot
bNotch = any(strcmpi(varargin, 'notch')); % declear which axes to plot

% First set the basic parameter
weeks = unique(varB);
nWeek = numel(weeks);
notch = false;
if bNotch
    notch = true;
end

if bBar
    bDots = false;
end

if bExperiment
    expFilter = myTable.ExperimentID == varargin{find(strcmpi(varargin, 'experiment'))+1};
    myTable = myTable(expFilter,:);
    varG = varG(expFilter,:);
    varX = varX(expFilter,:);
end

if ~iscategorical(varG)
    varG = categorical(varG);
end

if iscell(varX)
    varX = cell2mat(varX);
end

if ~bSame
     if bAxes
        plotAx = varargin{find(strcmpi(varargin, 'axes'))+1};
    else
        figure('WindowStyle', 'docked');
        plotAx = axes;
        hold on;
     end
else
    plotAx = gca;
    hold on;
end
uniG = categories(varG);
nCond = size(uniG,1);

semC = 'w';
if bBar
    semC = 'k';
    cla;
end

if bLabel
    yLab = varargin{find(strcmpi(varargin, 'label'))+1};
end

if bColor
    cmap = varargin{find(strcmpi(varargin, 'color'))+1};
else
    cmap = colorcube;
end

% Now adjust the data as needed
if beforeAfter
    scCond = varargin{find(strcmpi(varargin, 'secondCondition'))+1};
    secondCondtitions = unique(scCond);
    % Set the axis label
    firstLab = unique(varG);
    secondLab = unique(scCond);
    nMain = numel(firstLab);
    nSec = numel(secondLab);
    row1 = cell(nSec,nMain);
    for lab = 1:nMain
        if nSec==3
            row1(:,lab) = [' ', cellstr(firstLab(lab)), ' '];
        else
            row1(:,lab) = [cellstr(firstLab(lab)); repmat({' '}, nSec-1,1)];
        end
    end
    row1 = reshape(row1,1,numel(row1));
    row2 = cellstr(repmat(unique(scCond)',1,nMain));
    % Split the data according to the two categoricals
    beforeData = varX(scCond == secondCondtitions(1));
    afterData = varX(scCond == secondCondtitions(2));
    % The data should have the same dimension, if not show an error
    if numel(beforeData) ~= numel(afterData)
        errordlg('The data is not consistent', 'Plot Failed');
    else
        varX = [beforeData; afterData];
        groupB = [varG(scCond == secondCondtitions(1)); varG(scCond == secondCondtitions(2))];
        groupA = [scCond(scCond == secondCondtitions(1)); scCond(scCond == secondCondtitions(2))];
        varG = groupB .* categorical(groupA);
        varG = removecats(varG);
        uniG = unique(varG);
        nCond = size(uniG,1);
        bSecond = false;
    end
end

% assing the variable arguments
nSec = 0;
if bSecond
    nSub = 1;
    scCond = varargin{find(strcmpi(varargin, 'secondCondition'))+1};
    nSub = nCond;
    nSec = numel(unique(scCond));
    firstLab = unique(varG);
    if size(varX,2) > 1
        varB = repmat(varB,size(varX,2),1);
        varB = varB(:);
        myCond = repmat(varG,size(varX,2),1);
        scCond = varargin{find(strcmpi(varargin, 'secondCondition'))+1};
        if size(varX,1) > size(scCond,1)
            scCond = repmat(scCond, size(varX,1), 1);
            scCond = categorical(scCond(:));
        end
        if beforeAfter
            varG1 = myCond .* scCond;
            varX1 = varX(:);
            uniG = unique(varG1);
        else
            if bInvert
                varG = scCond .* myCond;
            else
                varG = myCond .* scCond;
            end
            varX = varX(:);
            uniG = unique(varG);
        end
        nCond = size(uniG,1);
    else
        if numel(varG) == numel(scCond)
            varG = varG .* categorical(scCond);
            varG = removecats(varG);
            uniG = unique(varG);
            nCond = size(uniG,1);
        else
        end
    end
    row1 = cell(nSec,nSub);
    for lab = 1:nSub
        if nSec==3
            row1(:,lab) = [' ', cellstr(firstLab(lab)), ' '];
        else
            row1(:,lab) = [cellstr(firstLab(lab)); repmat({' '}, nSec-1,1)];
        end
    end
    row1 = reshape(row1,1,numel(row1));
    row2 = cellstr(repmat(unique(scCond)',1,nSub));
end

if bNormal
    control = varargin{find(strcmpi(varargin, 'normalize'))+1};
    tempData = varX;
    for w = 1:nWeek
        tempWeek = weeks(w);
        weekFltr = varB == tempWeek;
        if numel(control) == 2
            controlMaxFltr = varG == control(1);
            controlMinFltr = varG == control(2);
            if bMedian
                tempMaxMean = nanmedian(varX(controlMaxFltr & weekFltr));
                tempMinMean = nanmedian(varX(controlMinFltr & weekFltr));
            else
                tempMaxMean = nanmean(varX(controlMaxFltr & weekFltr));
                tempMinMean = nanmean(varX(controlMinFltr & weekFltr));
            end
        else
            controlMaxFltr = varG == control;
            if bMedian
                tempMaxMean = nanmedian(varX(controlMaxFltr & weekFltr));
            else
                tempMaxMean = nanmean(varX(controlMaxFltr & weekFltr));
            end
            tempMinMean = 0;
        end
        tempData(weekFltr) = (varX(weekFltr) - tempMinMean) / (tempMaxMean - tempMinMean);
    end
    varX = tempData;
end

% if requested, save the data
if nargout == 1
    varargout{1} = varX;
end
% Now start to plot the data
xx = wisker(varG, varX, cmap, plotAx, nSec, notch);
%boxplot(varX, varG, 'Color', cmap(1:nCond,:), 'symbol','')


tX=1;
legCond = cell(nCond,1);
for c = 1:nCond
    tempCond = uniG(c);
    condFltr = varG == tempCond;
    if sum(condFltr) > 0
        tempX = varX(condFltr);
        if bBar
            patch(plotAx, [xx(tX)-.2 xx(tX)+.2 xx(tX)+.2 xx(tX)-.2], [0 0 nanmean(tempX) nanmean(tempX)], cmap(c,:), 'EdgeColor', cmap(c,:), 'FaceAlpha',.3)
        else
            plot(plotAx, [xx(tX)-.125 xx(tX)+.125], [nanmean(tempX) nanmean(tempX)], 'Color', 'w', 'LineWidth', 2)
        end
        sem = @(x) nanstd(x) ./ sqrt(sum(~isnan(x)));
        plot(plotAx, [xx(tX) xx(tX)], [(nanmean(tempX)-sem(tempX)) (nanmean(tempX)+sem(tempX))], 'color', semC, 'LineWidth', 2)
        if bDots
            if beforeAfter
                if mod(c,2) == 0
                    plot(plotAx, xx(tX) - 0.15, tempX, 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize',4,'MarkerFaceColor','w')
                    beforeY = varX(varG == uniG(c-1));
                    plot(plotAx, repmat([xx(tX-1)+.15 xx(tX)-.15], numel(tempX), 1)',[beforeY tempX]', '-', 'color', cmap(c,:), 'MarkerEdgeColor', cmap(c,:), 'MarkerSize',4,'MarkerFaceColor','w')
                else
                    plot(plotAx, xx(tX) + 0.15, tempX, 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize',4,'MarkerFaceColor','w')
                end
            else
                x = linspace(xx(tX) - 0.15, xx(tX) + 0.15, nWeek);
                for w=1:nWeek
                    tempWeek = weeks(w);
                    weekFltr = varB == tempWeek;
                    if sum(weekFltr & condFltr) > 0
                        y = varX(weekFltr & condFltr);
                        plot(plotAx, x(w),y, 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize',4,'MarkerFaceColor','w')
                    end
                end
            end
            legCond{c} = sprintf('%s (%d/%d)', char(tempCond), numel(tempX), nWeek);
        end
    end
    %         legCond{c} = sprintf('%s (%d/%d)', char(tempCond), numel(tempX), nWeek);
    legCond{c} = sprintf('%s', char(tempCond));
    tX = tX+1;
    
    
end

box(plotAx, 'off');
set(plotAx, 'TickDir', 'out');
ylim(plotAx, 'auto')
xlim(plotAx, [.5 xx(end)+.5])
if bSecond || beforeAfter
    set(gca, 'XTick', xx);
    labelArray = [row1; row2];
    labelArray = strjust(pad(labelArray),'center');
    tickLabels = sprintf('%s\\newline%s\n', labelArray{:});
%     tickLabels = strsplit(tickLabels);
    set(plotAx, 'XTickLabel', tickLabels);
    set(plotAx,'FontName','Arial')
else
    set(plotAx, 'XTick', xx);
    set(plotAx, 'XTickLabel', legCond);
end
if bLabel
    ylabel(plotAx, yLab);
end
if bFlip
    view([90 90]);
end
end

% wisker plot function
function tempX = wisker(varG, varY, cmap, plotAx, nSubGroup, notch)
% first divide the data on the varius groups
uniqueG = categories(varG);
nGroup = numel(uniqueG);
% get the data per group and calculate its values
tempX = 1:nGroup;
if nSubGroup > 1
    tempX = 0;
    for s=1:nGroup/nSubGroup
        tempS = max(s, tempX(end)+1);
        tempX = [tempX, tempS:.5:tempS+(0.5*nSubGroup)-0.5];
    end
    tempX = tempX(2:end);
end
for g=1:nGroup
    tempG = uniqueG(g);
    groupF = varG == tempG;
    tempY = varY(groupF);
    sortY = sort(tempY);
    quantY = quantile(sortY, [0.25 0.5 0.75]);
    minW = quantY(1) - 1.5*(quantY(3)-quantY(1));
    lowW = find(sortY>=minW,1,'first');
    minW = sortY(lowW);
    maxW = quantY(3) + 1.5*(quantY(3)-quantY(1));
    highW = find(sortY<=maxW,1,'last');
    maxW = sortY(highW);
    % Calculate the notch
    notchLow = quantY(2) - (1.57*(quantY(3)-quantY(1))) / sqrt(sum(~isnan(sortY)));
    notchHigh = quantY(2) + (1.57*(quantY(3)-quantY(1))) / sqrt(sum(~isnan(sortY)));
    % plot
    if ~notch
        patch(plotAx, [tempX(g)-.2 tempX(g)+.2 tempX(g)+.2 tempX(g)-.2], [quantY(1) quantY(1) quantY(3) quantY(3)], cmap(g,:), 'FaceAlpha', .3, 'EdgeColor', cmap(g,:));
        plot(plotAx, [tempX(g)-.2 tempX(g)+.2], [quantY(2) quantY(2)], 'color', cmap(g,:), 'LineWidth', 2);
    else
        patch(plotAx, [tempX(g)-.2 tempX(g)+.2 tempX(g)+.2 tempX(g)+.1 tempX(g)+.2 tempX(g)+.2 tempX(g)-.2 tempX(g)-.2 tempX(g)-.1 tempX(g)-.2 tempX(g)-.2],...
                      [quantY(1)   quantY(1)   notchLow    quantY(2)   notchHigh   quantY(3)   quantY(3)   notchHigh   quantY(2)   notchLow    quantY(1)],...
                      cmap(g,:), 'FaceAlpha', .3, 'EdgeColor', cmap(g,:));
        plot(plotAx, [tempX(g)-.1 tempX(g)+.1], [quantY(2) quantY(2)], 'color', cmap(g,:), 'LineWidth', 2);
    end
    
    plot(plotAx, [tempX(g) tempX(g)], [minW quantY(1)], 'color', cmap(g,:));
    plot(plotAx, [tempX(g) tempX(g)], [quantY(3) maxW], 'color', cmap(g,:));
end
end