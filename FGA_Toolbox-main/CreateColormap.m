function cmap = CreateColormap(cmapType, varargin)
% This function create the different colormap used in the notebook. The
% "divergin" is a red-to-blue colormap for the log2 plots; the "boxplot" is
% use a gradient of color representitive of the genotype
switch cmapType
    case "divergin"
        % Create divergin colormap, from [0 0 1] to [1 1 1], then [1 1 1] to [1 0 0];
        m1 = 10000*0.5;
        r = (0:m1-1)'/max(m1-1,1);
        g = r;
        r = [r; ones(m1,1)];
        g = [g; flipud(g)];
        b = flipud(r);
        cmap = flipud([r g b]);
    case "genotype"
        cmap1 = {'#252525', '#969696', '#006d2c', '#08519c'};
        cmap = nan(length(cmap1), 3);
        for c = 1:length(cmap1)
            cmap(c,:) = sscanf(cmap1{c}(2:end),'%2x%2x%2x',[1 3])/255;
        end
    case "condition"
        cmap1 = {'#252525','#969696',...
                 '#006d2c','#74c476',...
                 '#08519c','#6baed6'};
        cmap = nan(length(cmap1), 3);
        for c = 1:length(cmap1)
            cmap(c,:) = sscanf(cmap1{c}(2:end),'%2x%2x%2x',[1 3])/255;
        end
    otherwise % Assume that the colors are givens as a series of HEX keys
        cmap1 = varargin{1};
        cmap = nan(length(cmap1), 3);
        for c = 1:length(cmap1)
            cmap(c,:) = sscanf(cmap1{c}(2:end),'%2x%2x%2x',[1 3])/255;
        end
end
end