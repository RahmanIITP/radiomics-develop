function sDataCreation_FromDICOMpaths(pathSave,pathImages,pathRS,pathREG,pathRD,pathRP,nameSave)
% -------------------------------------------------------------------------
% function sDataCreation_FromDICOMpaths(pathSave,pathImages,pathRS,pathREG,pathRD,pathRP,nameSave)
% -------------------------------------------------------------------------
% DESCRIPTION: 
% This function read DICOM data according to the path info found in the
% input cells, and then organizes it in a 'sData' structure.
% -------------------------------------------------------------------------
% INPUTS:
% 1. pathSave: String specifying the full path to the directory where to 
%              save all the sData structures created by the current function.
%              --> Ex: '/home/myStudy/DATA'
% 2. pathImages: Cell of strings, where each string specifies the full path 
%                to a DICOM image of single volume.
%                --> Ex: cellPathVol{1} from readAllDICOM.m
% 3. pathRS: (optional). Cell of strings, where each string specifies the 
%            full path to a DICOM RTstruct of a single volume.
%            --> Options: - cellPathRS{1} from readAllDICOM.m
%                         - Empty array or cell ([],{})
%                         - No argument
% 4. pathREG: (optional). Cell of strings, where each string specifies the 
%             full path to a DICOM REG of a single volume.
%             --> Options: - cellPathREG{1} from readAllDICOM.m
%                          - Empty array or cell ([],{})
%                          - No argument if 'pathRD', 'pathRP' and 
%                            'nameSave' are also not provided
% 5. pathRD: (optional). Cell of strings, where each string specifies the 
%            full path to a DICOM RTdose of a single volume.
%            --> Options: - cellPathRD{1} from readAllDICOM.m
%                         - Empty array or cell ([],{})
%                         - No argument if 'pathRP' and 'nameSave' are also 
%                           not provided
% 6. pathRP: (optional). Cell of strings, where each string specifies the 
%            full path to a DICOM RTplan of a single volume.
%            --> Options: - cellPathRP{1} from readAllDICOM.m
%                         - Empty array or cell ([],{})
%                         - No argument if 'nameSave' is also not provided
% 7. nameSave: (optional). String specifying with what name the sData file
%              will be saved. If defined as 'modality', the Modality field 
%              of the DICOM headers of the imaging volume will also be used
%              for 'nameSave'. The saving format is the following:
%              '(PatientID)_(nameSave).(modality)scan.mat'
%              --> Options: - User-defined. Ex: 'myScanName'
%                           - No argument (default: 'SeriesDescription' 
%                             field of DICOM headers of imaging volume)
%                           - 'modality' 
% -------------------------------------------------------------------------
% OUTPUTS: Single sData file
% - sData: Cell of structures organizing the content of the volume data, 
%          DICOM headers, DICOM RTstruct* (used to compute the ROI) and 
%          DICOM REGstruct* (used to register a given volume to another),
%          DICOM RTdose* and DICOM RTplan*.
%          * If present in the sub-folder tree.
%    --> sData{1}: Explanation of cell content
%    --> sData{2}: Imaging data and ROI defintion
%    --> sData{3}: DICOM headers of imaging data
%    --> sData{4}: DICOM RTstruct (if applicable)
%    --> sData{5}: DICOM REGstruct (if applicable)
%    --> sData{6}: DICOM RTdose (if applicable)
%    --> sData{7}: DICOM RTplan (if applicable)
% -------------------------------------------------------------------------
% AUTHOR(S): 
% - Martin Vallieres <mart.vallieres@gmail.com>
% -------------------------------------------------------------------------
% HISTORY:
% - Creation: April 2017
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FINAL XYZ positions of spatialRef refers to the XYZ reference frame of 
% the image, not the DICOM one. For MRI rotations + sagittal + coronal
% images (for PET and CT: XYZ of image is XYZ of DICOM), apply the inverse 
% of sData{2}.scan.volume.scanRot to the XYZ grid of the image. To obtain
% the mask from a RTstruct, make sure to rotate the XYZ DICOM points of the
% RTstruct toi the XYZ reference frame of the image using 
% sData{2}.scan.volume.scanRot
%
% NOTE:
% - PixelSpacing and Slice spacing: XYZ image reference frame
% - ImagePositionPatient and ImageOrientation patient: XYZ DICOM reference
%   frame.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


startpath = pwd;
warning off

% PARTIAL PARSING OF ARGUMENTS
if nargin < 2
    error('At least two arguments must be provided')
end


% INITIALIZATION
sData = cell(1,7);


% CELL 1: EXPLANATIONS OF CELLS
sData{1} = struct('Cell_1','Explanation of cell content', ...
                  'Cell_2','Imaging data and ROI defintion', ...
                  'Cell_3','DICOM headers of imaging data', ...
                  'Cell_4','DICOM RTstruct (if applicable)', ...
                  'Cell_5','DICOM REG (if applicable)', ...
                  'Cell_6','DICOM RTdose (if applicable)', ...
                  'Cell_7','DICOM RTplan (if applicable)');
              
              
% CELL 2: IMAGING DATA AND ROI DEFINITION (if applicable)
    
    % 1. Reading DICOM images and headers
    nSlices = numel(pathImages); cellImages = cell(nSlices,1); dicomH = struct;
    for i = 1:nSlices
        dicomH = appendStruct(dicomH,dicominfo_correctWarning(pathImages{i}));
        cellImages{i} = double(dicomread(pathImages{i}));
    end
    
    % 2. Determination of the scan orientation
    mid = round(nSlices/2);
    dist = [abs(dicomH(mid+1).ImagePositionPatient(1) - dicomH(mid).ImagePositionPatient(1)), ...
            abs(dicomH(mid+1).ImagePositionPatient(2) - dicomH(mid).ImagePositionPatient(2)), ...
            abs(dicomH(mid+1).ImagePositionPatient(3) - dicomH(mid).ImagePositionPatient(3))];
    [~,index] = max(dist);
    if index == 1
        orientation = 'Sagittal';
        a = 2; b = 3; c = 1; 
    elseif index == 2
        orientation = 'Coronal';
        a = 1; b = 3; c = 2;
    else
        orientation = 'Axial';
        a = 1; b = 2; c = 3;
    end

    % 3. Sort the images and the dicom headers
    slicePositions = zeros(1,nSlices);
    for i = 1:nSlices
        slicePositions(i) = dicomH(i).ImagePositionPatient(index); % Using the right index (ax,sag,cor) only to sort image positions
    end
    [~,indices] = sort(slicePositions);
    sData{2}.scan.volume.data = cell2mat(reshape(cellImages(indices),[1,1,nSlices]));
    dicomH = dicomH(indices);

    % 4. Process volume
    type = dicomH(1).Modality;
    if strcmp(type,'PT') || strcmp(type,'CT')
        for i = 1:size(sData{2}.scan.volume.data,3)
            sData{2}.scan.volume.data(:,:,i) = sData{2}.scan.volume.data(:,:,i)*dicomH(i).RescaleSlope + dicomH(i).RescaleIntercept;
        end
    end
    type = [type,'scan'];
    sData{2}.type = type;

    % 5. Compute spatial properties --> DICOM REFERENCE FRAME
    sz = size(cellImages{1});
    Xgrid = zeros(sz(1),sz(2),nSlices);
    Ygrid = zeros(sz(1),sz(2),nSlices);
    Zgrid = zeros(sz(1),sz(2),nSlices);
    m = [dicomH(1).ImageOrientationPatient(1)*dicomH(1).PixelSpacing(1),dicomH(1).ImageOrientationPatient(4)*dicomH(1).PixelSpacing(2); ...
         dicomH(1).ImageOrientationPatient(2)*dicomH(1).PixelSpacing(1),dicomH(1).ImageOrientationPatient(5)*dicomH(1).PixelSpacing(2); ...
         dicomH(1).ImageOrientationPatient(3)*dicomH(1).PixelSpacing(1),dicomH(1).ImageOrientationPatient(6)*dicomH(1).PixelSpacing(2)];
    [I,J] = meshgrid(0:sz(2)-1,0:sz(1)-1); I = I(:); J = J(:); nPixel = numel(I);
    for i = 1:nSlices
        Xgrid(:,:,i) = reshape(([m(1,:),dicomH(i).ImagePositionPatient(1)] * [I,J,ones(nPixel,1)]')',[sz(1),sz(2)]);
        Ygrid(:,:,i) = reshape(([m(2,:),dicomH(i).ImagePositionPatient(2)] * [I,J,ones(nPixel,1)]')',[sz(1),sz(2)]);
        Zgrid(:,:,i) = reshape(([m(3,:),dicomH(i).ImagePositionPatient(3)] * [I,J,ones(nPixel,1)]')',[sz(1),sz(2)]);
    end
    
    % 6. Alignment of scan coordinates to image reference frame for
    % sagittal and coronal orientations, as if we were axial.
    % --> A better strategy could be employed, work on it.
    if strcmp(orientation,'Sagittal') || strcmp(orientation,'Coronal')
        tempXYZ = {Xgrid,Ygrid,Zgrid}; 
        eval(['Xgrid = tempXYZ{',num2str(a),'};']);
        eval(['Ygrid = tempXYZ{',num2str(b),'};']);
        eval(['Zgrid = tempXYZ{',num2str(c),'};']);
    end

    % 7. Alignment of scan coordinates for MR scans (inverse of
    % ImageOrientationPatient rotation matrix) --> IMAGE REFERENCE FRAME
    % (RTstruct points needs to be rotated the same).
    if strcmp(type,'MRscan')
        u = dicomH(1).ImageOrientationPatient(1:3); v = dicomH(1).ImageOrientationPatient(4:6);
        w = cross(u,v);
        A = [u,v,w];
        if strcmp(orientation,'Sagittal') || strcmp(orientation,'Coronal') % Alignment of scan coordinates to image reference frame (as if we were axial)
            A(1:3,:) = A([a,b,c],:);
        end
        A = A'; % Rotation matrix to apply to revert the initial rotation applied at scanning time
        newCoord = (A*[Xgrid(:)';Ygrid(:)';Zgrid(:)'])';
        Xgrid = reshape(newCoord(:,1),[sz(1),sz(2),nSlices]); Ygrid = reshape(newCoord(:,2),[sz(1),sz(2),nSlices]); Zgrid = reshape(newCoord(:,3),[sz(1),sz(2),nSlices]);
        sData{2}.scan.volume.scanRot = A;
        if A(3,3) < 0 % We then flip the 3rd dimension of the imaging volume and dicom headers
            sData{2}.scan.volume.data = flip(sData{2}.scan.volume.data,3);
            dicomH = flip(dicomH);
        end
    end

    % 8. Creation of imref3d object
    pixelX = dicomH(1).PixelSpacing(1); pixelY = dicomH(1).PixelSpacing(2);
    s1 = round(0.25*nSlices); s2 = round(0.25*nSlices) + 1; % Slices selected to calculate slice spacing (I have encountered problematic middle slices --> we go to one quarter of volume)  
    sliceS = sqrt(sum((dicomH(s1).ImagePositionPatient - dicomH(s2).ImagePositionPatient).^2)); % Slice Spacing
    spatialRef = imref3d([sz(1),sz(2),nSlices],pixelX,pixelY,sliceS);
    spatialRef.XWorldLimits = spatialRef.XWorldLimits - (spatialRef.XWorldLimits(1)-(min(Xgrid(:))-pixelX/2));
    spatialRef.YWorldLimits = spatialRef.YWorldLimits - (spatialRef.YWorldLimits(1)-(min(Ygrid(:))-pixelY/2));
    spatialRef.ZWorldLimits = spatialRef.ZWorldLimits - (spatialRef.ZWorldLimits(1)-(min(Zgrid(:))-sliceS/2));
    sData{2}.scan.volume.spatialRef = spatialRef;


% CELL 3: DICOM HEADERS OF IMAGING DATA
sData{3} = dicomH;


% CELL 4: DICOM RTstruct (if applicable)
if ~isempty(pathRS) && nargin > 2
    nRS = numel(pathRS);
    sData{4} = struct;
    for i = 1:nRS
        sData{4} = appendStruct(sData{4},dicominfo_correctWarning(pathRS{i}));
    end
end


% CELL 5: DICOM REG (if applicable)
if ~isempty(pathREG) && nargin > 3
    nREG = numel(pathREG);
    sData{5} = struct;
    for i = 1:nREG
        sData{5} = appendStruct(sData{5},dicominfo_correctWarning(pathREG{i}));
    end
end


% CELL 6: DICOM RTdose (if applicable)
if ~isempty(pathRD) && nargin > 4
    nRD = numel(pathRD);
    sData{6} = struct;
    for i = 1:nRD
        sData{6} = appendStruct(sData{6},dicominfo_correctWarning(pathRD{i}));
    end
end


% CELL 7: DICOM RTplan (if applicable)
if ~isempty(pathRP) && nargin > 5
    nRP = numel(pathRP);
    sData{7} = struct;
    for i = 1:nRP
        sData{7} = appendStruct(sData{7},dicominfo_correctWarning(pathRP{i}));
    end
end


% GATHER XYZ POINTS OF ROIs USING RTstruct
nRS = numel(sData{4});
contourNum = 0;
for rs = 1:nRS
    nROI = numel(fieldnames(sData{4}(rs).StructureSetROISequence));
    for roi = 1:nROI
        points = [];
        contourNum = contourNum + 1;
        itemROI = ['Item_',num2str(roi)]; % IMPORTANT: We should define another variable here --> roiNumb located at sData{4}(rs).StructureSetROISequence.(itemROI).ROINumber. This is probably the real link to sData{4}(rs).ROIContourSequence.(roiNumb).ContourSequence (TO BE VERIFIED FIRST IN DICOM DOCUMENTATION).
        try
            nameSet = sData{4}(rs).StructureSetName;
            nameSetInfo = 'StructureSetName';
            if strcmp(nameSet,'FIELD NOT PRESENT'), error; end
        catch
            try
                nameSet = sData{4}(rs).StructureSetDescription;
                nameSetInfo = 'StructureSetDescription';
                if strcmp(nameSet,'FIELD NOT PRESENT'), error; end
            catch
                try
                    nameSet = sData{4}(rs).SeriesDescription;
                    nameSetInfo = 'SeriesDescription';
                    if strcmp(nameSet,'FIELD NOT PRESENT'), error; end
                catch
                    nameSet = sData{4}(rs).SeriesInstanceUID;
                    nameSetInfo = 'SeriesInstanceUID';
                end
            end
        end
        sData{2}.scan.contour(contourNum).name = sData{4}(rs).StructureSetROISequence.(itemROI).ROIName;
        sData{2}.scan.contour(contourNum).nameSet = nameSet;
        sData{2}.scan.contour(contourNum).nameSetInfo = nameSetInfo;
        try
            nClosedContours = numel(fieldnames(sData{4}(rs).ROIContourSequence.(itemROI).ContourSequence)); indClosedContour = [];
            for s = 1:nClosedContours
                 itemSlice = ['Item_',num2str(s)];
                 pts_temp = sData{4}(rs).ROIContourSequence.(itemROI).ContourSequence.(itemSlice).ContourData; nPoints = numel(pts_temp)/3; % points stored in the RTstruct file for a given closed contour (beware: there can be multiple closed contours on a given slice).
                 if ~isempty(pts_temp) && isnumeric(pts_temp)
                     ind = 1:nPoints; indClosedContour = [indClosedContour;repmat(s,[nPoints,1])];
                     points = [points;pts_temp(ind*3-2),pts_temp(ind*3-1),pts_temp(ind*3)];
                 end
            end
            if strcmp(orientation,'Sagittal') || strcmp(orientation,'Coronal') % Alignment of scan coordinates to image reference frame (as if we were axial)
                points(:,1:3) = points(:,[a,b,c]);
            end
            sData{2}.scan.contour(contourNum).points_XYZ = [points,indClosedContour];
        catch
            sData{2}.scan.contour(contourNum).points_XYZ = NaN;
        end
    end
end
sData{2}.scan.orientation = orientation;
sData{2}.scan.patientPosition = sData{3}(1).PatientPosition;


% SAVING sData
if nargin < 7
    try
        nameSave = dicomH(1).SeriesDescription;
    catch
        nameSave = dicomH(1).SeriesInstanceUID;
    end
else
    if isempty(nameSave)
        try
            nameSave = dicomH(1).SeriesDescription;
        catch
            nameSave = dicomH(1).SeriesInstanceUID;
        end
    else
        if strcmp(nameSave,'modality')
            nameSave = sData{2}.type(1:(end-4));
        end
    end
end
nameSave = replaceCharacter(nameSave,'/','-');
nameSave = replaceCharacter(nameSave,'\','-');
nameSave = replaceCharacter(nameSave,' ','-');
nameSave = replaceCharacter(nameSave,'(','-');
nameSave = replaceCharacter(nameSave,')','-');
nameSave = replaceCharacter(nameSave,'&','-');
nameSave = replaceCharacter(nameSave,':','-');
nameSave = replaceCharacter(nameSave,'*','-');
nameID = sData{3}(1).PatientID;
nameID = replaceCharacter(nameID,'/','-');
nameID = replaceCharacter(nameID,'\','-');
nameID = replaceCharacter(nameID,' ','-');
nameID = replaceCharacter(nameID,'(','-');
nameID = replaceCharacter(nameID,')','-');
nameID = replaceCharacter(nameID,'&','-');
nameID = replaceCharacter(nameID,':','-');
nameID = replaceCharacter(nameID,'*','-');
cd(pathSave)
nameComplete = [nameID,'__',nameSave,'.',type,'.mat'];
save(nameComplete,'sData','-v7.3')
%fprintf('\n--> Creation of sData for %s: DONE',nameComplete(1:end-4));

cd(startpath)
end
