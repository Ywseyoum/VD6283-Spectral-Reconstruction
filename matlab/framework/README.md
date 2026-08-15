# MATLAB Spectral Reconstruction Framework

This folder contains the public-safe source version of the MATLAB framework developed during the spectral reconstruction project.

## What it does

The framework takes reference spectra and wavelength-dependent sensor response curves and supports three workflows:

- **Synthetic:** numerically integrates known spectra against channel-response curves to generate compact detector inputs.
- **Real:** imports measured multichannel detector readings and matches them to reference spectra.
- **Both:** runs the real and synthetic paths and creates a shared-channel comparison when possible.

It then trains and compares multiple reconstruction models, evaluates predicted spectra, generates figures, and exports trained-model packages and reports.

## Start here

In MATLAB, set this directory as the current folder and run:

```matlab
results = runSpectralReconstruction;
```

For the guided launcher, you can also run `START_HERE.m`.

To configure the workflow programmatically:

```matlab
s = defaultSpectralSettings;
s.pathwayMode = "synthetic";
results = runSpectralReconstruction(s);
```

## Models included

The framework can compare:

- Mean-spectrum baseline
- Ridge regression
- PLS regression
- PCA + linear regression
- PCA + ridge regression
- PCA + ensemble regression
- PCA + neural network
- PLS + neural network

The model-comparison routine uses held-out cross-validation when enough samples are available and ranks completed models using R², RMSE, and MAE together.

## Input formats

The import utilities support individual files and several combined-table orientations. Generic CSV examples are included in [`templates/`](templates/).

The code is designed to tolerate differences in file order, channel order, naming punctuation, repeat measurements, wavelength coverage, and common table layouts while recording transformations and warnings in the output.

## Output

A run can export:

- standardized spectral and detector inputs
- sample-matching reports
- validation folds
- model comparison/ranking tables
- predicted spectra
- per-sample metrics
- diagnostic figures
- trained model packages
- run summaries and warnings

## Public-release note

This repository intentionally **does not include raw lab measurements, internal SOPs, meeting notes, concentration worksheets, or other research working files** from the internship. The source code and generic templates are included to demonstrate the computational workflow without publishing internal or sample-specific research material.

## MATLAB requirements

Core preprocessing and numerical integration use standard MATLAB functionality. Some optional models require functions from MATLAB toolboxes, including `plsregress`, `fitrensemble`, and `fitnet`. Models whose required functions are unavailable are designed to be skipped rather than stopping the entire comparison.

## Validation note

This public copy was statically reviewed before publication, but it was not re-executed in the environment used to prepare this repository because a MATLAB runtime was not available there.
