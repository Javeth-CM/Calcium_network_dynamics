function rasterPlot(varY, varargin)
%RASTERPLOT Create raster plots based on data and inputs
% Inputs arguments:
%	varY: Input data, specified as a n-by-m matrix, of 'n' regions and 'm' frames
%
% Name Only Arguments      
%	'Area': Decision to plot the convolved area of the raster plot
%
% Name-Value Pair Arguments
%	'Axes' - Axes handle: Declear which axes to plot.
%	'varX' - array: Additional variable for the x axis, specidied as a 1-by-m array
%   'Threshold' - integer: Add a red dotted line to indicate the threshold for the number of points in the raster
%	'XLabel' - text: Text to use to label the X-axis.
%	'YLabel' - text: Text to use to label the Y-axis.
%	'MultipleROIs' - array: Boolean array to divide the raster plot into subgroups of cells
%	
% See also: PLOT, PATCH

% Author: Alessandro Moro
% Dept. Functional Genomics,
% Center for Neurogenomics and Cognitive Research (CNCR),
% email: a.moro@vu.nl

% First check the arguments
bAxes = false | any(strcmpi(varargin, 'axes'));
bVarX = false | any(strcmpi(varargin, 'varX'));
bArea = false | any(strcmpi(varargin, 'area'));
bThreshold = false | any(strcmpi(varargin, 'threshold'));
bXLabel = false | any(strcmpi(varargin, 'xlabel'));
bYLabel = false | any(strcmpi(varargin, 'ylabel'));
bMultiple = false | any(strcmpi(varargin, 'MultipleROIs'));
bSilent = false | any(strcmpi(varargin, 'RemoveSilent'));

% Get the axes were to plot the data
if bAxes
    axPlot = varargin{find(strcmpi(varargin, 'axes'))+1};
else
    axPlot = axes;
end
hold(axPlot, 'on');

% The data should be divided in column (one cell per column). Most likely there are more frames than points
if size(varY,1) < size(varY,2)
    varY = varY';
end
if bVarX
    varX = varargin{find(strcmpi(varargin, 'varX'))+1};
else
    varX = 1:size(varY,1);
end

% Remove the silent cells
if bSilent
    silentFltr = all(isnan(varY));
    varY(:,silentFltr) = [];
    % Change the number in the raster to reflect the cells that we removed
    varY(~isnan(varY)) = 1;
    varY = varY .* repmat(1:size(varY,2), size(varY,1), 1);
end

% See if we need to plot the area underneath the raster and start the plot
if bArea
    areaRaster = varY;
    areaRaster(~isnan(areaRaster)) = 1;
    areaRaster(isnan(areaRaster)) = 0;
    areaRaster = sum(areaRaster,2);
    smoothWindow = gausswin(10);
    smoothWindow = smoothWindow / sum(smoothWindow);
    areaRaster = filter(smoothWindow, 1, areaRaster);
    area(axPlot, varX, areaRaster, 'FaceColor', 'k', 'FaceAlpha', 0.3, 'EdgeColor', 'none')
    [networkPeaks, networkLocs] = findpeaks(areaRaster, 8, 'MinPeakProminence', 2.5);
    plot(axPlot, networkLocs, networkPeaks, 'ok');
    title(sprintf('Max network frequency: %.1f', numel(networkPeaks)/2));
end

% See if we need a threshold and plot it
if bThreshold
    thr = varargin{find(strcmpi(varargin, 'threshold'))+1};
    isActive = sum(any(~isnan(varY)));
    for thr = 0.1:.1:1
        if thr==.8
            plot(axPlot, varX, ones(numel(varX),1)*thr*isActive, '--r', 'LineWidth', 2)
        else
            plot(axPlot, varX, ones(numel(varX),1)*thr*isActive, '--r')
        end
    end
end

% Now plot the actual data
if bMultiple
    roiSet = varargin{find(strcmpi(varargin, 'MultipleROIs'))+1};
    plot(axPlot, varX, varY(:,~roiSet), '-k')
    plot(axPlot, varX, varY(:,roiSet), 'Color', [49,130,189]/255, 'LineWidth', 2)
else
    plot(axPlot, varX, varY, '-k')
end

% Garnish the plot
axPlot.Box = 'off';
axPlot.TickDir = 'out';
if bXLabel
    xlabel(axPlot, varargin{find(strcmpi(varargin, 'xlabel'))+1});
end
if bYLabel
    ylabel(axPlot, varargin{find(strcmpi(varargin, 'ylabel'))+1});
end
end