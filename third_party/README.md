# Third-party components

- `epanet_matlab_toolkit/` is EPANET-MATLAB Toolkit 2.2.6.5. Its licence and
  citation notice are copied beside this file.
- `epanet_matlab_toolkit_patch/epanet.m` is the same toolkit class with the two
  Apple-Silicon loader changes documented in that directory. It is added to
  the front of the MATLAB path and therefore overrides only the upstream class.
- `epanet22_arm64/` is an Apple-Silicon build of official EPANET 2.2 with its
  source headers and licence. Other platforms may use the toolkit's bundled
  native library or set `WDS_EPANET_TOOLKIT` to a system installation.

These components retain their upstream licences. They are not covered by any
future licence chosen for the article-specific MATLAB code.
