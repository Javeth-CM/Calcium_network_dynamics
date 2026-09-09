function mergeFiles()
%MERGEFILES - Merge all CSV files in a specified folder
% Description: Merges multiple CSV files from a selected folder into a
%              single CSV file.
%
% Syntax: mergeFiles()
%
% Usage: The function does not require any input arguments. When called,
%        it opens a graphical user interface (GUI) to guide the user
%        through the merging process.
%
% Steps:
% 1. The user is prompted to select the folder that contains the CSV files
%    they want to merge.
% 2. The function reads all the CSV files in the selected folder.
% 3. It concatenates the data from each CSV file into a single data table.
% 4. The user is prompted to provide a name and location for the merged
%    CSV file to be saved.
% See also: READTABLE,  WRITETABLE

% Prompt the user to select the folder containing the CSV files to be merged.
dataDir = uigetdir(pwd, 'Select folder containing the files you want to merge');
oldDir = cd(dataDir); % Store the current directory to revert back later.

% Get the list of file names matching the '*.csv' pattern in the selected folder.
filePattern = fullfile(dataDir, '*.csv');
dataFiles = dir(filePattern);

% Prompt the user to choose a name and location for the merged CSV file to be saved.
saveFile = uiputfile('*.csv', 'Merged File');

% Loop through each CSV file and merge the data into a single data table.
for d = 1:height(dataFiles)
    if d == 1
        % For the first file, create the initial merged data table.
        mergeData = readtable(dataFiles(d).name);
    else
        % For subsequent files, concatenate their data to the merged data table.
        mergeData = [mergeData; readtable(dataFiles(d).name)];
    end
end

% Write the merged data table to the specified CSV file.
writetable(mergeData, saveFile)

% Return to the original working directory.
cd(oldDir)
end