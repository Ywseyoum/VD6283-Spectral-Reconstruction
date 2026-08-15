# VD6283 Spectral Reconstruction

**MATLAB-based fluorescence spectral reconstruction using the VD6283 multispectral sensor, signal processing, numerical integration, and machine learning.**

## Overview

This repository documents a research internship project investigating whether a compact six-channel multispectral sensor can be used to estimate a much higher-dimensional fluorescence emission spectrum.

The work combined experimental fluorescence measurements, VD6283 sensor characterization, MATLAB data processing, physics-informed response simulation, and machine-learning regression. A public-safe version of the MATLAB reconstruction framework is included in [`matlab/framework/`](matlab/framework/).

## Project Goal

A conventional fluorescence spectrum contains intensity values across many wavelengths, while the VD6283 provides only six detector responses. The central question was:

> **Can a six-channel optical sensor be used to estimate a full fluorescence emission spectrum?**

The reconstruction target used approximately **400–700 nm at 1 nm spacing**, corresponding to 301 spectral output values.

## VD6283 Sensor Channels

The project used six sensor channels:

- Blue
- Green
- Red
- Infrared (IR)
- Visible
- Clear

The workflow supports raw, maximum-based, or reference-channel normalization. Clear was used as the reference channel in the main modeling workflow developed during the project.

## Research Workflow

`Spectral / sensor data → Import → Clean → Interpolate → Normalize → Integrate → Model → Validate → Visualize`

The framework supports:

1. Flexible import of reference spectra and wavelength-dependent sensor response curves.
2. Wavelength-grid alignment, repeat averaging, and missing/negative-value handling.
3. Synthetic detector generation by integrating each spectrum against each channel response curve.
4. Import and matching of real multichannel detector measurements.
5. Synthetic-only, real-only, or combined real/synthetic pathways.
6. Multiple regression and machine-learning reconstruction models.
7. Cross-validation and model comparison using R², RMSE, MAE, and additional spectral diagnostics.
8. Export of predictions, figures, trained models, matching reports, and run summaries.

## Two Data Paths

### Synthetic / Training Path

A larger fluorescence reference dataset from **PhotochemCAD** supported machine-learning development. Known fluorescence spectra were combined with characterized VD6283 channel sensitivities to simulate the response expected from each detector channel.

This produced paired examples of compact detector inputs and full fluorescence-spectrum targets. Approximately **130 fluorophore spectra** were represented in the modeling dataset used during the project.

### Experimental / Real Path

Fluorescent samples were also measured experimentally using the VD6283 and fluorescence reference instrumentation. Those measurements formed a separate real-data pathway for characterization, testing, and comparison.

**Important distinction:** the small set of lab-prepared fluorescent samples was not the dataset used to train the main machine-learning model. The larger PhotochemCAD-based dataset supported model development, while the experimental measurements were handled separately.

## Machine-Learning Reconstruction

The public framework includes the following model families:

- Mean-spectrum baseline
- Ridge regression
- PLS regression
- PCA + linear regression
- PCA + ridge regression
- PCA + ensemble regression
- PCA + neural network
- PLS + neural network

In one reported project comparison, **PCA + Neural Network** outperformed **PLS + Neural Network**:

| Model | RMSE | R² |
|---|---:|---:|
| PLS + Neural Network | 0.1287 | 0.8202 |
| **PCA + Neural Network** | **0.0977** | **0.8965** |

The framework itself is more general than that single comparison and can evaluate several model families under the same workflow.

## Repository Structure

```text
VD6283-Spectral-Reconstruction/
├── README.md
├── .gitignore
├── matlab/
│   ├── README.md
│   └── framework/
│       ├── runSpectralReconstruction.m
│       ├── defaultSpectralSettings.m
│       ├── predictNewSpectra.m
│       ├── functions/
│       └── templates/
├── data/
│   └── README.md
├── results/
│   └── README.md
└── docs/
    └── methodology.md
```

## Public Source Release

The reusable MATLAB framework source and generic CSV templates are included here. The public repository intentionally **does not include raw lab measurements, internal SOPs, meeting notes, concentration worksheets, or other sample-specific research working files** from the internship.

This keeps the repository useful as a technical portfolio while avoiding publication of internal research material.

## Tools & Skills Demonstrated

- MATLAB
- Data cleaning and preprocessing
- Numerical integration
- Spectral data analysis
- Multispectral sensor characterization
- Fluorescence spectroscopy
- Principal Component Analysis (PCA)
- Partial Least Squares (PLS)
- Neural-network regression
- Cross-validation and model comparison
- Scientific visualization
- Experimental and synthetic-data workflow design

## Running the Public Framework

Open [`matlab/framework/`](matlab/framework/) in MATLAB and run:

```matlab
results = runSpectralReconstruction;
```

See the framework README for supported input layouts, model options, generic templates, and MATLAB-toolbox notes.

> **Validation note:** the source was statically reviewed before publication, but this public copy was not re-executed in the environment used to prepare the repository because a MATLAB runtime was unavailable there.

## Project Significance

This work explored whether compact multispectral sensing combined with computational reconstruction can recover richer spectral information than the raw detector outputs provide. More broadly, it demonstrates how a small optical sensor can be paired with numerical modeling and machine learning to approximate measurements normally associated with more specialized spectroscopic hardware.
