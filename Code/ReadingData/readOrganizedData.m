function readOrganizedData(pathPatient,pathSave,namePatient)
% -------------------------------------------------------------------------
% AUTHOR(S): 
% - Martin Vallieres <mart.vallieres@gmail.com>
% -------------------------------------------------------------------------
% HISTORY:
% - Creation: March 2018
% -------------------------------------------------------------------------
% DISCLAIMER:
% "I'm not a programmer, I'm just a scientist doing stuff!"
% -------------------------------------------------------------------------
% STATEMENT:
% This file is part of <https://github.com/mvallieres/radiomics-develop/>, 
% a private repository dedicated to the development of programming code for
% new radiomics applications.
% --> Copyright (C) 2017  Martin Vallieres
%     All rights reserved.
%
% This file is written on the basis of a scientific collaboration for the 
% "radiomics-develop" team.
%
% By using this file, all members of the team acknowledge that it is to be 
% kept private until public release. Other scientists willing to join the 
% "radiomics-develop" team is however highly encouraged. Please contact 
% Martin Vallieres for this matter.
% -------------------------------------------------------------------------

startpath = pwd;

% INITIALIZATION
cd(pathPatient), listScans = dir;
listScans = listScans(~ismember({listScans.name},{'.','..','.DS_Store','._.DS_Store'}));
nScans = numel(listScans);


for s = 1:nScans
    scan = listScans(s).name;
    cd(fullfile(pathPatient,scan))
    ok = zeros(1,4);
    
    % STEP 1: READING DICOM DATA (there must be DICOM data present in the directory for now --> minimim requirement is to report on image acquisition parameters).
    try
        compressedDICOM = logical(exist('DICOMseries.tgz','file'));
        if compressedDICOM
            untar('DICOMseries.tgz','tempFolder')
        end
        readAllDICOM(pwd,pwd,0,'matlab','modality');
        if compressedDICOM
            if ispc
                system('rmdir /q /s tempFolder'); % Deleting the temporary created folder.
            else
                system('rm -r tempFolder'); % Deleting the temporary created folder.
            end
        end
        listMat = dir('*.mat'); % There must be only one scan series in the organized patient-scan folder
        sData = load(listMat(1).name); sData = struct2cell(sData); sData = sData{1};
        delete('*.mat')
        sData{2}.scan.volume.data = single(sData{2}.scan.volume.data); % Native format is int16. But in this function, for the moment, we save all volumes in single. TO SOLVE TO MINIMIZE SPACE.
        nameSave = [namePatient,'__',scan,'.',sData{2}.type,'.mat'];
        ok(1) = 1;
        dcmVol = true;
    catch % PROBLEM WITH DICOM DATA. CODE DOWN THE ROAD WILL FAIL. TO MANUALLY CORRECT. DICOM DATA MUST BE PRESENT AND READABLE.
        sData = cell(1,7); % EMPTYsData
        nameSave = [namePatient,'__',scan,'.ERRORdicom.mat'];
        cd(pathSave), save(nameSave,'sData','-v7.3')
        continue
    end
    
    % STEP 2: NIFITI FILES
    % --> SOLVE THE ORIENTATION OF FILES. There A 90 degree rotation with DICOM.
    % --> TO ADD: TRY/CATCH FOR ERRORS
    listNIFTI = dir('*.nii*'); % The second * means that we allow compressed nifti (.nii.gz)
    if ~isempty(listNIFTI)
        if exist('imagingVolume.nii') || exist('imagingVolume.nii.gz')
            ok(2) = 1;
            while true % If the nifti file is compressed, it appears that only one gunzip call (for unzipping, inside niftiread and niftiinfo) can be executed on the system at a time. This is a big problem for parallelization. Temporary loop here. TO SOLVE.
                try
                    sData{2}.nii.volume.data = single(niftiread('imagingVolume'));
                    sData{2}.nii.volume.header = niftiinfo('imagingVolume');
                    break
                catch
                    pause(ceil(5*rand(1))); % Wait between 1 and 5 seconds (randomly chosen) before trying again --> different threads should not get stuck.
                end
            end
            listMask = dir('segMask*.nii*'); nMask = numel(listMask);
            sData{2}.nii.mask = struct;
            if dcmVol
                sData{2}.scan.volume.data = []; % For the moment, we do not save both a .nii volume and the dicom volume.
                dcmVol = false; % In case other types of data are also present, we do not want to create an empty array in sData{2}.scan.volume.data once gain, it has already been done.
            end
            for m = 1:nMask
                nameMaskFile = listMask(m).name;
                indUnderScore = strfind(nameMaskFile,'_');
                indDot = strfind(nameMaskFile,'.');
                if numel(indUnderScore) == 2
                    nameROI = nameMaskFile((indUnderScore(1)+1):(indUnderScore(2)-1));
                    labelROI = str2num(nameMaskFile((indUnderScore(2)+6):(indDot(1)-1)));
                else % Then there must be only one underscore
                    nameROI = nameMaskFile((indUnderScore(1)+1):(indDot(1)-1));
                    labelROI = 1;
                end
                sData{2}.nii.mask(m).name = nameROI;
                while true % If the nifti file is compressed, it appears that only one gunzip call (for unzipping, inside niftiread and niftiinfo) can be executed on the system at a time. This is a big problem for parallelization. Temporary loop here. TO SOLVE.
                    try
                        sData{2}.nii.mask(m).data = niftiread(nameMaskFile);
                        sData{2}.nii.mask(m).header = niftiinfo(nameMaskFile);
                        break
                    catch
                        pause(ceil(5*rand(1))); % Wait between 1 and 5 seconds (randomly chosen) before trying again --> different threads should not get stuck.
                    end
                end
                sData{2}.nii.mask(m).data(sData{2}.nii.mask(m).data ~= labelROI) = NaN;
                sData{2}.nii.mask(m).data(sData{2}.nii.mask(m).data == labelROI) = 1;
                sData{2}.nii.mask(m).data(isnan(sData{2}.nii.mask(m).data)) = 0;
                sData{2}.nii.mask(m).data = uint16(sData{2}.nii.mask(m).data); % Mask has only 1's and 0's. To save as logical type?
            end
        end
    end    
    
    % STEP 3: VERIFY FOR THE PRESENCE OF .nnrd files
    listNRRD = dir('*.nrrd');
    if ~isempty(listNRRD)
        if exist('imagingVolume.nrrd') % We recommend to always provide "imagingVolume.nrrd" if .nrrd segmentation is performed. However, it may still happen that the only imagin volume present comes from the DICOM data.
            ok(3) = 1;
            try
                [sData{2}.nrrd.volume.data,sData{2}.nrrd.volume.header] = nrrdread('imagingVolume.nrrd'); sData{2}.nrrd.volume.data = single(sData{2}.nrrd.volume.data);
            catch
                nameSave = [namePatient,'__',scan,'.ERRORnrrd.mat'];
                cd(pathSave), save(nameSave,'sData','-v7.3')
                continue
            end
            if dcmVol
                sData{2}.scan.volume.data = []; % For the moment, we do not save both a .nrrd volume and the dicom volume.
                dcmVol = false; % In case other types of data are also present, we do not want to create an empty array in sData{2}.scan.volume.data once gain, it has already been done.
            end
        else
            sData{2}.nrrd.volume.data = sData{2}.scan.volume.data; % Copied from DICOM data for now, in case the user only provided a segmentation mask in .nrrd format (and no imaging volume in .nrrd, only DICOM).
            sData{2}.nrrd.volume.header = 'None -- Imaging volume = DICOM data';
        end
        listMask = dir('segMask*.nrrd'); nMask = numel(listMask);
        sData{2}.nrrd.mask = struct;
        errorMask = false;
        for m = 1:nMask
            nameMaskFile = listMask(m).name;
            indUnderScore = strfind(nameMaskFile,'_');
            indDot = strfind(nameMaskFile,'.');
            if numel(indUnderScore) == 2
                nameROI = nameMaskFile((indUnderScore(1)+1):(indUnderScore(2)-1));
                labelROI = str2num(nameMaskFile((indUnderScore(2)+6):(indDot(1)-1)));
            else % Then there must be only one underscore
                nameROI = nameMaskFile((indUnderScore(1)+1):(indDot(1)-1));
                labelROI = 1;
            end
            sData{2}.nrrd.mask(m).name = nameROI;
            try
                [sData{2}.nrrd.mask(m).data,sData{2}.nrrd.mask(m).header] = nrrdread(nameMaskFile);
            catch
                errorMask = true;
                break
            end
            sData{2}.nrrd.mask(m).data(sData{2}.nrrd.mask(m).data ~= labelROI) = NaN;
            sData{2}.nrrd.mask(m).data(sData{2}.nrrd.mask(m).data == labelROI) = 1;
            sData{2}.nrrd.mask(m).data(sData{2}.nrrd.mask(m).data ~= labelROI) = 0;
            sData{2}.nrrd.mask(m).data = uint16(sData{2}.nrrd.mask(m).data); % Mask has only 1's and 0's. To save as logical type?
       end
       if errorMask
            nameSave = [namePatient,'__',scan,'.ERRORnrrd.mat'];
            cd(pathSave), save(nameSave,'sData','-v7.3')
            continue
       end
    end
   
    % STEP 4: VERIFY FOR THE PRESENCE OF .img files
    % --> TO ADD: TRY/CATCH FOR ERRORS
    listIMG = dir('*.img');
    if ~isempty(listIMG)
        if exist('imagingVolume.img')
            ok(4) = 1;
            sData{2}.img.volume.data = single(niftiread('imagingVolume'));
            sData{2}.img.volume.header = niftiinfo('imagingVolume');
            listMask = dir('segMask*.img'); nMask = numel(listMask);
            sData{2}.img.mask = struct;
            if dcmVol
                sData{2}.scan.volume.data = []; % For the moment, we do not save both a .img volume and the dicom volume.
                dcmVol = false; % In case other types of data are also present, we do not want to create an empty array in sData{2}.scan.volume.data once gain, it has already been done.
            end
            for m = 1:nMask
                nameMaskFile = listMask(m).name;
                indUnderScore = strfind(nameMaskFile,'_');
                indDot = strfind(nameMaskFile,'.');
                if numel(indUnderScore) == 2
                    nameROI = nameMaskFile((indUnderScore(1)+1):(indUnderScore(2)-1));
                    labelROI = str2num(nameMaskFile((indUnderScore(2)+6):(indDot(1)-1)));
                else % Then there must be only one underscore
                    nameROI = nameMaskFile((indUnderScore(1)+1):(indDot(1)-1));
                    labelROI = 1;
                end
                sData{2}.img.mask(m).name = nameROI;
                sData{2}.img.mask(m).data = niftiread(nameMaskFile(1:end-4));
                sData{2}.img.mask(m).header = niftiinfo(nameMaskFile(1:end-4));
                sData{2}.img.mask(m).data(sData{2}.img.mask(m).data ~= labelROI) = NaN;
                sData{2}.img.mask(m).data(sData{2}.img.mask(m).data == labelROI) = 1;
                sData{2}.img.mask(m).data(isnan(sData{2}.img.mask(m).data)) = 0;
                sData{2}.img.mask(m).data = uint16(sData{2}.img.mask(m).data); % Mask has only 1's and 0's. To save as logical type?
            end
        end
    end
   
    % STEP 4: SAVE FINAL "sData" FILE
    if sum(ok) % Otherwise, no imaging volume was present or without error, so there is nothing to save.
        cd(pathSave), save(nameSave,'sData','-v7.3')
    end
end

cd(startpath)
end
