function S = loadParams(foldername)
    fid = fopen(fullfile(foldername, 'params.py'), 'r');
    C = textscan(fid, '%s%s', 'Delimiter', '=', 'ReturnOnError', false);
    fclose(fid);
    
    cName = C{1};
    cValue = C{2};
    
    for iC = 1:length(cName)
        sNum = str2double(cValue{iC});
        sValue = strip(cValue{iC}, '''');
        sName = strip(cName{iC});
        if strcmpi(sValue, 'false')
            S.(sName) = false;
        elseif strcmpi(sValue, 'true')
            S.(sName) = true;
        elseif isnan(sNum)
            S.(sName) = sValue;
        else
            S.(sName) = sNum;
        end
    end
end