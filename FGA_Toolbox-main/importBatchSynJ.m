function resultTable = importBatchSynJ(dataDir)
% get the file names
filePattern = fullfile(dataDir, '*.csv');
dataFiles = dir(filePattern);

% define the variables to import
opts = delimitedTextImportOptions("NumVariables", 6);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["Var1", "Region", "Area", "Morphology", "Synapses", "Other"];
opts.VariableTypes = ["double", "string", "double", "double", "double", "double"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Import the data
resultTable = table;
tempTable = table;
hWait = waitbar(0, 'Loading data');
for file = 1:numel(dataFiles)
    waitbar(file/numel(dataFiles), hWait, sprintf('Loading data (%.3f%%)', file/numel(dataFiles)*100));
    filePath = fullfile(dataFiles(file).folder, dataFiles(file).name);
    tempResult = readtable(filePath, opts);
    % Create the final table data
    cellID = dataFiles(file).name;
    cellID = cellID(9:end-4);
    fileName = regexp(cellID, '_', 'split');
    weekID = fileName(1);
    condID = fileName(2);
    coverslipID = fileName(3);
    fovID = fileName(4);
    nSoma = sum(contains(tempResult.Region, 'Soma'));
    somaArea = tempResult{1:nSoma,'Area'};
    somaMorphology = tempResult{1:nSoma,'Morphology'};
    somaSynapses = tempResult{1:nSoma,'Synapses'};
    somaOther = tempResult{1:nSoma,'Other'};
    neuriteLength = tempResult{nSoma+1,'Area'};
    neuriteMorphology = tempResult{nSoma+1,'Morphology'};
    neuriteSynapses = tempResult{nSoma+1,'Synapses'};
    neuriteOther = tempResult{nSoma+1,'Other'};
    synapsesArea = tempResult{nSoma+2:end,'Area'};
    synapsesMorphology = tempResult{nSoma+2:end,'Morphology'};
    synapsesSynapses = tempResult{nSoma+2:end,'Synapses'};
    synapsesOther = tempResult{nSoma+2:end,'Other'};
    if file == 1
        % Names
        resultTable.CellID = {cellID};
        resultTable.week = weekID;
        resultTable.Condition = condID;
        resultTable.Coverslip = coverslipID;
        resultTable.FOV = fovID;
        % Soma
        resultTable.somaNumber = nSoma;
        resultTable.somaArea = {somaArea};
        resultTable.somaMorphology = {somaMorphology};
        resultTable.somaSynapses = {somaSynapses};
        resultTable.somaOther = {somaOther};
        % Neurites
        resultTable.neuriteLength = neuriteLength;
        resultTable.neuriteMorphology = neuriteMorphology;
        resultTable.neuriteSynapses = neuriteSynapses;
        resultTable.neuriteOther = neuriteOther;
        % Synapses
        resultTable.synapsesArea = {synapsesArea};
        resultTable.synapsesMorphology = {synapsesMorphology};
        resultTable.synapsesSynapses = {synapsesSynapses};
        resultTable.synapsesOther = {synapsesOther};
    else
        % Names
        tempTable.CellID = {cellID};
        tempTable.week = weekID;
        tempTable.Condition = condID;
        tempTable.Coverslip = coverslipID;
        tempTable.FOV = fovID;
        % Soma
        tempTable.somaNumber = nSoma;
        tempTable.somaArea = {somaArea};
        tempTable.somaMorphology = {somaMorphology};
        tempTable.somaSynapses = {somaSynapses};
        tempTable.somaOther = {somaOther};
        % Neurites
        tempTable.neuriteLength = neuriteLength;
        tempTable.neuriteMorphology = neuriteMorphology;
        tempTable.neuriteSynapses = neuriteSynapses;
        tempTable.neuriteOther = neuriteOther;
        % Synapses
        tempTable.synapsesArea = {synapsesArea};
        tempTable.synapsesMorphology = {synapsesMorphology};
        tempTable.synapsesSynapses = {synapsesSynapses};
        tempTable.synapsesOther = {synapsesOther};
        % Merge the tables
        resultTable = [resultTable; tempTable];
    end
end
close(hWait);
% resultTable.week = categorical(weeknum(datetime(resultTable.week, 'InputFormat', 'yyMMdd')));
resultTable.week = categorical(resultTable.week);
end