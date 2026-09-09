function plotStimulation(stimType, varargin)
% Plot stimulation

if any(strcmpi(varargin, 'barHeight'))
    barHeight = varargin{find(strcmpi(varargin, 'barHeight'))+1};
else
    barHeight = 100;
end
switch stimType
    case '2x8'
        if any(strcmpi(varargin, 'stimTime'))
            stimTime = varargin{find(strcmpi(varargin, 'stimTime'))+1};
            stimS = stimTime(1:2);
            stimD = stimTime(3);
        else
            stimS = [30 71.5];
            stimD = 1.5;
        end
        if ~any(strcmpi(varargin, 'sameFigure'))
            figure('WindowStyle' ,'docked');
        end
        hold on
        for s=1:2
            for i=0:7
                patch([stimS(s)+(stimD*i) stimS(s)+1+(stimD*i) stimS(s)+1+(stimD*i) stimS(s)+(stimD*i)], [0 0 barHeight barHeight], [.7 .9 1], 'EdgeColor', 'none', 'FaceAlpha',.3)
            end
        end
    case 'TBS'
        if ~any(strcmpi(varargin, 'sameFigure'))
            figure('WindowStyle' ,'docked');
            hold on;
        end
        patch([10 15 15 10], [0 0 100 100], [.7 .9 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
        patch([105 110 110 105], [0 0 100 100], [.7 .9 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
        for i = 0:20:40
            for j = 0:.2:1.8
                patch([(30+i)+j (30.04+i)+j (30.04+i)+j (30+i)+j], [0 0 barHeight barHeight], [.7 .9 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
            end
        end
        clear i j;
    case '200Hz'
        if ~any(strcmpi(varargin, 'sameFigure'))
            figure('WindowStyle' ,'docked');
            hold on;
        end
        for i = 10:30:70
            patch([i i+20 i+20 i], [0 0 barHeight barHeight], [.7 .9 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
        end
        for i = 30:30:60
            patch([i i+1 i+1 i], [0 0 barHeight barHeight], [.1 .1 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
        end
        for i = 35:30:65
            patch([i i+1 i+1 i], [0 0 barHeight barHeight], [.1 .1 1], 'EdgeColor', 'none', 'FaceAlpha', .3);
        end
        clear i;
end