function [x, applied, violation] = project_feasible(x, ub, nonlcon, tolerance)
%PROJECT_FEASIBLE Move minimally toward the feasible upper-bound design.

[c, ceq] = nonlcon(x);
violation = max([0; c(:); abs(ceq(:))]);
applied = violation > tolerance;
if ~applied
    return;
end

[c_upper, ceq_upper] = nonlcon(ub);
upper_violation = max([0; c_upper(:); abs(ceq_upper(:))]);
if upper_violation > tolerance
    error('wdn:NoFeasibleUpperBound', ...
        'The upper-bound design is infeasible (violation %.6g).', upper_violation);
end

base = x;
lower_fraction = 0;
upper_fraction = 1;
for iteration = 1:60
    fraction = (lower_fraction + upper_fraction) / 2;
    candidate = base + fraction * (ub - base);
    [candidate_c, candidate_ceq] = nonlcon(candidate);
    candidate_violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
    if candidate_violation <= tolerance / 10
        upper_fraction = fraction;
    else
        lower_fraction = fraction;
    end
end

% A tiny extra step avoids returning on the infeasible side of EPANET's
% hydraulic numerical tolerance.
upper_fraction = min(1, upper_fraction + 1e-8);
x = base + upper_fraction * (ub - base);
[c, ceq] = nonlcon(x);
violation = max([0; c(:); abs(ceq(:))]);
end
