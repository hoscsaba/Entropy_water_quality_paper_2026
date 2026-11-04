function chlorine = chlorine_state(d, ~)
%CHLORINE_STATE Return the terminal state of the configured quality model.
% ENsolveQ advances the same EPANET 2.2 transport model as the former toolkit
% time-series wrapper. Only the terminal state is read because all objectives
% in this project use the concentration at the configured final time.

d.solveCompleteQuality;
quality_raw = d.getNodeActualQuality;
chlorine = double(quality_raw(:));
end
