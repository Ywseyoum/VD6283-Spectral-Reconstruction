# Methodology

## Objective

The project investigated reconstruction of a fluorescence emission spectrum from the six outputs of a VD6283 multispectral sensor.

## Sensor Representation

The modeled sensor response for a channel can be described conceptually as the wavelength integral of the sample spectrum multiplied by that channel's wavelength-dependent sensitivity.

For channel `c`:

```text
response(c) = integral[ spectrum(lambda) * sensitivity(c, lambda) ] d(lambda)
```

This transforms a high-dimensional reference spectrum into the compact response expected from the physical sensor.

## Preprocessing

The MATLAB workflow included:

- importing spectral and sensor-channel data
- cleaning invalid or missing values
- interpolating measurements onto compatible wavelength grids
- calculating or processing detector sensitivity curves
- normalizing responses to a reference channel (Clear)
- assembling model inputs and target spectra

## Synthetic Modeling Path

Reference fluorescence spectra from a larger fluorophore collection were combined with the VD6283 sensitivity curves. Numerical integration generated a six-channel response vector for each known spectrum.

These response-spectrum pairs provided training examples for machine-learning reconstruction.

## Experimental Path

Experimental fluorescent samples were measured separately. These measurements supported real-data characterization and comparison, but they should not be described as the dataset that trained the main reconstruction model.

## Reconstruction

Because each target spectrum contains hundreds of wavelength values while the sensor provides only six measurements, dimensionality reduction was investigated before regression.

Two evaluated approaches included:

- Partial Least Squares (PLS) + neural network
- Principal Component Analysis (PCA) + neural network

In the reported comparison, PCA + neural network achieved the better overall reconstruction metrics.

## Evaluation

Reconstructed spectra were compared with known/reference spectra using:

- Root Mean Squared Error (RMSE)
- Coefficient of Determination (R²)
- predicted-versus-reference spectral plots

The workflow was intended to evaluate how much spectral information could be computationally recovered from a compact multispectral measurement.
