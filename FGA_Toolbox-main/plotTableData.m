function plotTableData(varX, varY, varC, plotType, varargin)
%

conds = unique(varC);
nCond = numel(conds);
% color map
if any(strcmpi(varargin, 'color'))
    cmap = varargin{find(strcmpi(varargin, 'color'))+1};
else
    cmap = [0 0 0;
        %     cmap = [0.678 0.251 0.149;
        0.058 0.506 0.251;
        0.196 0.600 0.600;
        0.942 0.401 0.250;
        0.700 0.900 1.000];
    if nCond >= 5
        cmap = parula(nCond);
    end
end

if iscell(varY) && ~strcmp(plotType, 'dual')
    varY = cell2mat(varY);
end

if any(strcmpi(varargin, 'splitAxis'))
    splitAx = varargin{find(strcmpi(varargin, 'splitAxis'))+1};
    nFrames = numel(varX);
    spaceFactor = (varX(end) - varX(1)) / (nFrames - 1);
    firstTime = varX(1):spaceFactor:splitAx(1);
    splitTime = linspace(splitAx(1), splitAx(2), splitAx(3));
    lastTime = (splitAx(2) + spaceFactor):spaceFactor:nFrames;
    varX = [firstTime splitTime lastTime];
    varX = varX(1:nFrames);
end
switch plotType
    case 'line'
        fillX = [varX fliplr(varX)];
        for c=1:nCond
            tempFltr = varC == conds(c);
            tempData = varY(tempFltr,:);
            tempData(isnan(tempData)) = 0;
            tempMean = nanmean(tempData);
            tempSEM = nanstd(tempData) ./ sqrt(sum(~isnan(tempData(:,1))));
            fillY = [(tempMean-tempSEM) fliplr(tempMean+tempSEM)];
            fill(fillX,fillY,cmap(c,:),'EdgeColor','none','FaceAlpha',.1)
            hL(c) = plot(varX, tempMean, 'Color', cmap(c,:), 'LineWidth', 1, 'Marker', 's');
            legName{c} = sprintf('%s [%d]', char(conds(c)), sum(~isnan(tempData(:,1))));
        end
        legend(hL, legName); legend boxoff;
        set(gca, 'TickDir', 'out');
    case 'stairs'
        semX = [varX(1:end-1);varX(2:end);varX(2:end);varX(1:end-1)];
        for c=1:nCond
            tempFltr = varC == conds(c);
            tempData = varY(tempFltr,:);
            tempMean = nanmean(tempData);
            tempSEM = nanstd(tempData) ./ sqrt(sum(~isnan(tempData(:,1))));
            semY = [(tempMean-tempSEM); (tempMean-tempSEM); (tempMean+tempSEM); (tempMean+tempSEM)];
            patch(semX, semY, cmap(c,:), 'EdgeColor', 'none', 'FaceAlpha', .1);
%             if conds(c) == '1KO'
%                 hL(c) = stairs(varX(1:end-1), tempMean, 'Color', cmap(c,:), 'LineWidth', 1, 'Marker', '<', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize', 4);
%             elseif conds(c) == '2KO'
%                 hL(c) = stairs(varX(1:end-1), tempMean, 'Color', cmap(c,:), 'LineWidth', 1, 'Marker', '>', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize', 4);
%             elseif conds(c) == '3KO'
%                 hL(c) = stairs(varX(1:end-1), tempMean, 'Color', cmap(c,:), 'LineWidth', 1, 'Marker', 'v', 'MarkerEdgeColor', cmap(c,:), 'MarkerSize', 4);
%             else
                hL(c) = stairs(varX(1:end-1), tempMean, 'Color', cmap(c,:), 'LineWidth', 1);
%             end
            legName{c} = sprintf('%s [%d]', char(conds(c)), sum(~isnan(tempData(:,1))));
        end
        if any(strcmpi(varargin, 'splitAxis'))
            splitAx = varargin{find(strcmpi(varargin, 'splitAxis'))+1};
            patch([splitAx(1) splitAx(2) splitAx(2) splitAx(1)], [0 0 100 100], 'w', 'EdgeColor', 'none')
            set(gca, 'XTick', 0:5:120);
            set(gca, 'XTickLabel', [-30:5:15, 40:5:90])
        end
        legend(hL, legName); legend boxoff;
        set(gca, 'TickDir', 'out');
    case 'ridge'
        semX = [varX(1:end-1);varX(2:end);varX(2:end);varX(1:end-1)];
        ridgeOrder = varargin{1};
        newBase = fliplr(linspace(0, nCond*0.01, nCond));
        cB = 1;
        for c = ridgeOrder
            tempFltr = varC == conds(c);
            tempData = varY(tempFltr,:) + newBase(cB);
            tempMean = nanmedian(tempData);
            tempSEM = nanstd(tempData) ./ sqrt(sum(~isnan(tempData(:,1))));
            semY = [(tempMean-tempSEM); (tempMean-tempSEM); (tempMean+tempSEM); (tempMean+tempSEM)];
            patch(semX, semY, cmap(c,:), 'EdgeColor', 'none', 'FaceAlpha', .1);
            stairs(varX(1:end-1), tempMean, 'Color', cmap(c,:), 'LineWidth', 1);
            legName{cB} = sprintf('%s [%d]', char(conds(c)), sum(~isnan(tempData(:,1))));
            cB = cB+1;
        end
        set(gca, 'YTick', fliplr(newBase))
        set(gca, 'YTickLabel', fliplr(legName))
    case 'dual'
        conds = unique(varC);
        nCond = numel(conds);
        semX = [varX(1:end-1);varX(2:end);varX(2:end);varX(1:end-1)];
        if nCond < 4
            s1 = 1;
            s2 = nCond;
        else
            s1 = round(nCond / 2);
            s2 = round(nCond / 2);
        end
        figure
        for c = 1:nCond
            subplot(s1,s2,c);
            hold on
            for i=0:7
                patch([5+(1.5*i) 5+1+(1.5*i) 5+1+(1.5*i) 5+(1.5*i)], [0 0 100 100], [.7 .9 1], 'EdgeColor', 'none');
            end
            tempFltr = varC == conds(c);
            lS = {'s-' 'o-'};
            for s = 1:2
                tempData = cell2mat(varY(tempFltr,s));
                tempMean = nanmean(tempData);
                tempSEM = nanstd(tempData) ./ sqrt(sum(~isnan(tempData(:,1))));
                semY = [(tempMean-tempSEM); (tempMean-tempSEM); (tempMean+tempSEM); (tempMean+tempSEM)];
                patch(semX, semY, cmap(c,:), 'EdgeColor', 'none', 'FaceAlpha', .1);
                hL(s) = plot(varX(1:end-1)+.25, tempMean, lS{s}, 'Color', cmap(c,:), 'MarkerFaceColor', 'w', 'MarkerEdgeColor', cmap(c,:));
            end
            title(char(conds(c)))
            set(gca, 'TickDir', 'out');
            if c == 1
                legend(hL, {'First'; 'Second'}, 'Location', 'best'); legend boxoff;
            end
        end
    case 'sholl'
        figure('WindowStyle', 'docked');
        hold on
        % Set soma to -1 no matter what it was specified by the user to
        % give distance
        varX(1) = -10;
        for c=1:nCond
            tempFltr = varC == conds(c);
            tempData = varY(tempFltr,:);
            tempMean = nanmean(tempData);
            tempSEM = nanstd(tempData) ./ sqrt(sum(~isnan(tempData(:,1))));
            if any(strcmpi(varargin, 'normalize'))
                yyaxis left
                errorbar(varX(1), tempMean(1), tempSEM(1), 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerFaceColor', 'w', 'CapSize', 0, 'Color', cmap(c,:));
                yyaxis right
                hL(c) = errorbar(varX(2:end), tempMean(2:end), tempSEM(2:end), 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerFaceColor', 'w', 'CapSize', 0, 'Color', cmap(c,:));
            else
                hL(c) = errorbar(varX, tempMean, tempSEM, 'o', 'MarkerEdgeColor', cmap(c,:), 'MarkerFaceColor', 'w', 'CapSize', 0, 'Color', cmap(c,:));
            end
            legName{c} = sprintf('%s [%d]', char(conds(c)), sum(~isnan(tempData(:,1))));
        end
        legend(hL, legName); legend boxoff;
        if any(strcmpi(varargin, 'normalize'))
            yyaxis left
            ylabel('Soma Intensity (a.u.)');
            yyaxis right
            ylabel('Intensity (%)');
        else
            set(gca,'YAxisLocation','origin')
            ylabel('Intensity (a.u.)');
        end
        set(gca, 'TickDir', 'out');
        xlim([-15 numel(varX)-1]);
        xlabel('Distance from soma (\mum)');
    otherwise
            helpdlg('Only ''line'', ''stairs'' or ''dual''');
end