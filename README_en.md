# TOptLab · Topology Optimization Laboratory

> **About the name**: `TOptLab` stands for **T**opology **Opt**imization **Lab**oratory, pointing directly to its core purpose — the rapid validation of topology optimization algorithms. `TOpt` is a widely used abbreviation in the field of topology optimization, making the name easy to search for and easy to share.

## Project Overview

This project aims to build a **function library for the rapid validation of topology optimization algorithms**, implemented using pure MATLAB syntax with no dependency on third-party toolboxes. The current plan consists of two core modules:

- **Finite element library** — see folder `fem`
- **Topology optimization library** — see folder `TOfuncs`

## Directory Structure

| Directory  | Description                        |
| ---------- | ---------------------------------- |
| `fem`      | Finite element library             |
| `TOfuncs`  | Topology optimization library      |
| `test`     | Test scripts                       |

## Finite Element Module

The base files are taken from [CALFEM](https://calfem.com), a finite element toolbox for MATLAB.

> A finite element toolbox for MATLAB. © Division of Structural Mechanics and Division of Solid Mechanics, Lund University

### Changelog

- **`assem()`**: Improved the speed of assembling large stiffness matrices; function signature modified.
- **`extract_ed()`**: Improved the speed of extracting element displacements from the global displacement vector; function signature modified.
- **`solveq()`**: Optimized memory usage and computational speed for solving very large equilibrium systems.
- **`soli8s()`**: Added the `ir = 1` (1×1×1 centre point) integration rule; fixed the shear-component order to `[sigxy sigyz sigxz]`; removed the integration-point loop so all integration points are evaluated in a single vectorized pass; and made the routine fully loop-free when all elements share the same geometry.

## Topology Optimization Module

All functions are currently written by the author, and the module is still under active development.

### Changelog

- **`BESO_update()`**: Updates design variables according to the BESO algorithm rules based on sensitivities and a target volume; supports both hard-kill and soft-kill schemes, and allows marking non-design domains via `passive`.
- **`elemental_filter_prepare()`**: Builds the element-based filter convolution kernel `h` and its weight-sum matrix `Hs`, supporting 2D and 3D design domains (via `conv2` / `convn` respectively).
- **`nodal_filter_prepare()`**: Builds a node-based filter, including the node weight sums, the weight kernel, and an element-to-node value transformation matrix.
- **`plot_metrics()`**: Plots multiple metrics against iteration number and automatically saves the figures and data files (PNG, FIG, CSV).
- **`display_2D()`**: Displays a 2D topology scalar field (first argument is the density `rho`), with a name-value interface matching `display_3D`; elements with `rho <= 0.5` are hidden automatically, and it supports a shading field, mask, color range, colormap, colorbar, and an FPTO2D-like smooth-boundary display.
- **`display_3D()`**: Displays a 3D topology in two modes switched by `Smooth`: voxel cubes colored per element by a scalar field, or a smoothed `isosurface` view (top3D125 blue-body coloring); supports a shading field, mask, color range, colormap, and colorbar.
- **`model2STL()`**: Generates an STL file from a model (cube / smoothed isosurface modes), based on the Top3D extension `Top3dSTL_v3.m`, for 3D printing or post-processing; supports binary/ASCII format, density cutoff, face color and alpha, element edge lengths, and optional visualization.
