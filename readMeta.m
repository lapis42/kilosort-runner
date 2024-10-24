function meta = readMeta(binFile)
    % Parse meta file into a struct
    metaFile = replace(binFile, '.bin', '.meta');
    if ~isfile(metaFile)
        meta = struct();
        return
    end
    
    % Read all lines at once
    fileContent = fileread(metaFile);
    lines = strsplit(fileContent, '\n');
    
    % Initialize meta struct
    meta = struct();
    
    % Process each line
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line) || line(1) == '%'
            continue
        end
        
        parts = strsplit(line, '=');
        if length(parts) ~= 2
            continue
        end
        
        tag = strtrim(parts{1});
        value = strtrim(parts{2});
        
        if tag(1) == '~'
            tag = tag(2:end);
            switch tag
                case 'imroTbl'
                    meta.(tag) = regexp(value, '\d+ \d+ \d+ \d+ \d+ \d+', 'match');
                case 'snsChanMap'
                    meta.(tag) = cell2mat(cellfun(@(x) str2double(strsplit(x, {':', ';'}))', regexp(value, '\d+;\d+:\d+', 'match'), 'UniformOutput', false))';
                case 'snsShankMap'
                    meta.(tag) = regexp(value, '\d+:\d+:\d+:\d+', 'match');
                case 'snsGeomMap'
                    [header, data] = parseGeomMap(value);
                    meta.([tag, '_header']) = header;
                    meta.(tag) = data;
                    meta.prbName = header{1};
            end
        else
            meta.(tag) = str2double(value);
            if isnan(meta.(tag))
                meta.(tag) = value;
            end
        end
    end
end

function [header, data] = parseGeomMap(value)
    headerMatch = regexp(value, '[a-zA-Z0-9_]+,\d+,\d+,\d+', 'match');
    header = strsplit(headerMatch{1}, ',');
    dataMatches = regexp(value, '\d+:\d+:\d+:\d+', 'match');
    data = cell2mat(cellfun(@(x) str2double(strsplit(x, ':'))', dataMatches, 'UniformOutput', false))';
end