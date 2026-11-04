# Minimal EPANET-MATLAB Toolkit macOS patch

`epanet.m` was copied from the existing project toolkit.  Only native-library
loading was changed: `filesep` replaces a Windows-only backslash and the Unix
branch passes the full dynamic-library path to MATLAB `loadlibrary`.

Keeping this copy in the new workspace avoids modifying the original toolkit.

