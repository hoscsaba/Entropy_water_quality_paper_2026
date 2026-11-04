# EPANET runtime files

The loader copies the authoritative file from `../input` here before opening it.
EPANET-MATLAB Toolkit temporary INP, BIN and report files therefore never modify
or clutter the authoritative network input.
Randomly named EPANET binary scratch files may remain here after an interrupted
MATLAB run; they are generated material and are safe to replace on the next run.
