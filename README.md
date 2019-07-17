# Welcome to _radiomics-develop_!

This is a repository dedicated to the development of programming code for new radiomics applications (IBSI compliant!) via collaborative work with other scientific colleagues. I look forward to work with you! Please do not hesitate to contact me if you have any question: Martin Vallières, 1-514-839-0248, mart.vallieres@gmail.com

## Recent developments
- IBSI calibration test -- Phase 2: Image processing with CT data (June 2018)
- IBSI calibration test -- Phase 1: Feature calculation with digital phantom (April 2018)
- Now using CSV files as inputs for roiNames (April 2018)
- Addition and subtraction of ROIs now allowed, with operations parsed in roiNames.csv files (April 2018)
- Compatibility with input imaging data of the following format: .nrrd and .img/.hdr (April 2018)
- Wavelet features (August 2017)
- Re-organization of radiomics structure (August 2017)
- Definition of definite/aboslute/filter imaging intensities (August 2017)
- Visualization tool to check ROIs on images with manualROIchoice=true (August 2017)

## Installation
1. Install `git` on your computer. In Linux, this goes simply by running `sudo apt-get install git` in the terminal.
2. Clone this online repository to your preferred location on your computer by running `git clone https://github.com/mvallieres/radiomics-develop.git` in the terminal. 

## Instructions
- **COMPUTATION OF RADIOMIC FEATURES**: Please follow the instructions in the _INSTRUCTIONS.txt_ file at <https://github.com/mvallieres/radiomics-develop/tree/master/WORKSPACE_RadiomicComputation>
- **IBSI calibration test -- Phase 1: Feature calculation with digital phantom**: Please follow the instructions in the _INSTRUCTIONS.txt_ file at <https://github.com/mvallieres/radiomics-develop/tree/master/Tests/IBSI_FeatureCalculation>
- **IBSI calibration test -- Phase 2: Image processing with CT patient data**: Please follow the instructions in the _INSTRUCTIONS.txt_ file at <https://github.com/mvallieres/radiomics-develop/tree/master/Tests/IBSI_ImageProcessing>
- Other applications to come (multivariable modeling) ...

## Documentation
- Full list of features and image processing steps are defined by the [Imaging Biomarker Standardisation Initiative](https://arxiv.org/abs/1612.07003).
- Example applications of how to use texture features extracted using multiple parameters can be found in [M Vallières et al 2015 Phys. Med. Biol. 60 5471](https://doi.org/10.1088/0031-9155/60/14/5471) and in [M Vallières et al 2017 Sci. Rep. 7:10117](http://dx.doi.org/10.1038/s41598-017-10371-5)

## Warning
- By default, GLCM, GLRLM and NGTDM matrices are using distance corrections as originally defined in [M Vallières et al 2015 Phys. Med. Biol. 60 5471](https://doi.org/10.1088/0031-9155/60/14/5471). Resulting features for these matrices will thus be slightly different from the benchmarked features defined by the [Imaging Biomarker Standardisation Initiative](https://arxiv.org/abs/1612.07003). 
- _Moran's I index_, _Geary's C measure_ and _Global intensity peak_ features  are at the moment disabled. The reason is that these features take too long to compute the way they are written now. We need to find a way to vectorize their computation or to use valid approximations with faster computation methods. 
- Comments and definitions of input and output arguments in the different pieces of code are not integrated yet. This is a work in progress.

## Future work
1. Multivariable modeling.
2. Image post-processing (PVE corrections for PET, intensity nonuniformity corrections for MRI, etc.)

#### DISCLAIMER
"I'm not a programmer, I'm just a scientist doing stuff!"

#### STATEMENT
Copyright (C) 2017-2019  Martin Vallières  
All rights reserved.

