function [spikeRise, spikeDecay, spikeProperties] = CalciumRiseAndDecay(dataIn, spikesIn, Fs, param, options)
% CALCIUMRISEANDDECAY is an implementation of the FINDPEAKS function where multiple parameters on the peaks are calculated and reported
%   Inputs: dataIn   -> a m-x-n matrix of all the ROIs in one FOV, where m is the number of ROIs and n the number of frames
%           spikesIn -> a m-x-1 cell array containing the location of the already detected spikes
%           Fs       -> Imaging frequency in Hz
%           param    -> structure containing the user parameters to detect a spike
%           options  -> structure containing quantification options:
%                       . UseParallel  = boolean for using the parallel computing or not
%                       . TrainNetwork = boolean to get the traces label to train a random forest (experimental)
%                       . UseTrained   = boolean to use a pretrained dataset to label the trace (experimental)

% Loop through all the identified peaks to find the left and right bounds
nTraces = size(dataIn, 1);
spikeRise = cell(nTraces, 1);
spikeDecay = cell(nTraces, 1);
spikeProperties = cell(nTraces, 8); % timeToPeak, 25, 50, 75, 90% width, prominence, timeToDecay, DecayTau
for t = 1:nTraces
    if contains(param.DetectTrace, 'Raw')
        tempData = dataIn(t,:);
    else
        tempData = wdenoise(dataIn(t,:), 'DenoisingMethod', 'BlockJS');
    end
    % Calculate all the local minima
    allValleys = islocalmin(tempData);
    spikeLocs = spikesIn{t} + 1;
    nSpikes = numel(spikeLocs);
    indexLB = nan(5, nSpikes);
    indexRB = nan(5, nSpikes);
    promInt = nan(1, nSpikes);
    durations = nan(4,nSpikes);
    decayTauA = nan(1, nSpikes);
    decayTauB = nan(1, nSpikes);
    for s = 1:nSpikes
        % Left bound
        if s == 1
            tempStart = 1;
        else
            tempStart = spikeLocs(s-1);
        end
        % Walk backwards until there is not a valley at the right prominence
        bStart = false;
        tempEnd = spikeLocs(s);
        valleyInt = tempData(spikeLocs(s));
        valleyCount = 0;
        while ~bStart && (tempEnd > tempStart)
            tempIdx = find(allValleys(tempStart:tempEnd), 1, 'last')  + tempStart -1;
            if ~isempty(tempIdx)
                % Find the deepest valley
                if valleyInt > tempData(tempIdx)
                    valleyInt = tempData(tempIdx);
                    tempLB = tempIdx;
                    tempEnd = tempIdx - 1;
                    valleyCount = valleyCount + 1;
                else
                    % There was a deeper valley
                    bStart = true;
                end
            else
                bStart = true;
                if valleyCount == 0
                    tempLB = tempStart;
                end
            end
        end
        indexLB(1,s) = tempLB;
        % Right bound
        if s == nSpikes
            tempEnd = length(tempData)-1;
        else
            tempEnd = spikeLocs(s+1);
        end
        % Walk forward to find the end as the valley closer to the basline value, or another peak
        bEnd = false;
        tempStart = spikeLocs(s);
        valleyInt = tempData(tempLB);
        lastValley = find(allValleys(tempStart:tempEnd), 1, 'last') + tempStart -1;
        preValley = spikeLocs(s);
        if isempty(lastValley)
            lastValley = tempEnd;
        end
        while ~bEnd
            % Since we have an indication of the baseline, use this value to calculate where the decay should stop
            tempIdx = find(allValleys(tempStart:tempEnd), 1, 'first') + tempStart -1;
            if ~isempty(tempIdx)
                % Find the closet valley to the basline
                if round(tempData(tempIdx),2) > round(valleyInt,2)
                    tempStart = tempIdx + 1;                    
                else
                    bEnd = true;
                    tempRB = tempIdx;
                end
            else
                tempStart = tempStart + 1;
            end
            if tempStart >= lastValley
                % We are very far, so let's try to see if the valley is actually the lowest
                valleys = [preValley, lastValley];
                [~,valleyIdx] = min(tempData(valleys));
                tempRB = valleys(valleyIdx);
                bEnd = true;
            else
                preValley = tempIdx;
            end
        end
        if isempty(tempIdx)
            tempIdx = tempEnd;
        end
        indexRB(1,s) = tempRB;
        % Now calculate the duration at 25, 50, 75, and 90% of the height
        if indexLB(1,s) > indexRB(1,s)
            indexLB(1,s) = max(1, find(tempData(1:indexRB(1,s)) >= tempData(indexRB(1,s)), 1));
        end
        baseInt = min(tempData(indexLB(1,s):indexRB(1,s)));
        promInt(s) = tempData(spikeLocs(s)) - baseInt;
        durationMarks = baseInt + promInt(s) .* [.25 .5 .75 .9];
        for dm = 1:4
            durationIdx = find(tempData(indexLB(1,s):indexRB(1,s)) >= durationMarks(dm));
            diffIdx = find(gradient(durationIdx)>1, 1, 'first');
            if isempty(diffIdx)
                diffIdx = numel(durationIdx);
            end
            durations(dm,s) = numel(durationIdx) / Fs;
            indexLB(dm+1,s) = max(1,durationIdx(1) + indexLB(1,s) -2);
            indexRB(dm+1,s) = durationIdx(diffIdx) + indexLB(1,s);
        end
    end
    % Calculate the decay constant
    expFit = fittype( 'exp1' );
    fitOpts = fitoptions( 'Method', 'NonlinearLeastSquares' );
    fitOpts.Display = 'Off';
    fitOpts.Normalize = 'On';
    fitOpts.StartPoint = [0 0];
    if options.UseParallel
        % First chop the trace into the right sizes (supposedly speeding up the parallel computing)
        chopData = cell(1, nSpikes);
        for s = 1:nSpikes
            chopData{s} = tempData(spikeLocs(s):indexRB(1,s));
        end
        parfor s = 1:nSpikes
            expFit = fittype( 'exp1' );
            fitOpts = fitoptions( 'Method', 'NonlinearLeastSquares' );
            fitOpts.Display = 'Off';
            fitOpts.Normalize = 'On';
            fitOpts.StartPoint = [0 0];
            decayTrace = chopData{s};
            decayTime = (1:numel(decayTrace)) / Fs;
            if numel(decayTrace) > 2
                decayFit = fit(decayTime', decayTrace', expFit, fitOpts);
                % To get the fitted trace use: fitTrace = decayFit.a * exp(decayFit.b .* ((decayTime-mean(decayTime))/std(decayTime)));
                %decayTauA(1,s) = decayFit.a;
                decayTauB(1,s) = -1*(decayFit.b)^-1;
            end
        end
    else
        for s = 1:nSpikes
            decayTrace = tempData(spikeLocs(s):indexRB(1,s));
            decayTime = (1:numel(decayTrace)) / Fs;
            if numel(decayTrace) > 2
                decayFit = fit(decayTime', decayTrace', expFit, fitOpts);
                % To get the fitted trace use: fitTrace = decayFit.a * exp(decayFit.b .* ((decayTime-mean(decayTime))/std(decayTime)));
                decayTauA(1,s) = decayFit.a;
                decayTauB(1,s) = -1*(decayFit.b)^-1;
            end
        end
    end
    % Store the data
    spikeRise{t} = indexLB;
    spikeDecay{t} = indexRB;
    spikeProperties{t,1} = (spikeLocs - indexLB(1,:)) / Fs;
    spikeProperties{t,2} = durations(1,:);
    spikeProperties{t,3} = durations(2,:);
    spikeProperties{t,4} = durations(3,:);
    spikeProperties{t,5} = durations(4,:);
    spikeProperties{t,6} = promInt;
    spikeProperties{t,7} = (indexRB(1,:) - spikeLocs) / Fs;
    spikeProperties{t,8} = decayTauB;
end
end
