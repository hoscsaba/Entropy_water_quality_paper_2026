function [best_x, best_f, exitflag, output] = simple_ga(fitness, nonlcon, x0, lb, ub, options)
%SIMPLE_GA Toolbox-free continuous genetic optimiser with feasible-first ranking.

population_size = max(4, round(options.population_size));
nvars = numel(x0);
population = lb + rand(population_size, nvars) .* (ub - lb);
population(1, :) = min(max(x0, lb), ub);
elite_count = max(1, ceil(0.05 * population_size));
stall = 0;
function_count = 0;
best_f = inf;
best_violation = inf;
best_x = population(1, :);
history = nan(options.max_generations, 2);

for generation = 1:options.max_generations
    [values, violations] = evaluate_population(population);
    order = feasible_first_order(values, violations);
    generation_best = order(1);
    candidate_f = values(generation_best);
    candidate_v = violations(generation_best);

    improved = candidate_v < best_violation - options.function_tolerance || ...
        (candidate_v <= options.function_tolerance && ...
         best_violation <= options.function_tolerance && ...
         candidate_f < best_f - options.function_tolerance);
    if improved
        best_x = population(generation_best, :);
        best_f = candidate_f;
        best_violation = candidate_v;
        stall = 0;
    else
        stall = stall + 1;
    end
    history(generation, :) = [best_f, best_violation];

    if strcmpi(options.display, 'iter')
        fprintf('Generation %d: objective %.8g, violation %.3g\n', ...
            generation, best_f, best_violation);
    end
    if stall >= options.max_stall_generations
        break;
    end

    next_population = population(order(1:elite_count), :);
    mutation_scale = 0.20 * (1 - (generation - 1) / max(options.max_generations, 1)) + 0.01;
    while size(next_population, 1) < population_size
        parent1 = tournament(population, values, violations);
        parent2 = tournament(population, values, violations);
        alpha = rand(1, nvars);
        child = alpha .* parent1 + (1 - alpha) .* parent2;
        mutate = rand(1, nvars) < max(1 / nvars, 0.10);
        child(mutate) = child(mutate) + ...
            mutation_scale .* (ub(mutate) - lb(mutate)) .* randn(1, sum(mutate));
        child = min(max(child, lb), ub);
        next_population(end + 1, :) = child; %#ok<AGROW>
    end
    population = next_population(1:population_size, :);
end

if best_violation <= options.function_tolerance
    exitflag = 1;
    message = 'Feasible solution returned by wdn.simple_ga.';
else
    exitflag = -2;
    message = 'No feasible solution found by wdn.simple_ga.';
end
output.generations = generation;
output.funccount = function_count;
output.best_constraint_violation = best_violation;
output.history = history(1:generation, :);
output.message = message;

    function [values, violations] = evaluate_population(candidates)
        count = size(candidates, 1);
        values = inf(count, 1);
        violations = inf(count, 1);
        for row = 1:count
            try
                values(row) = fitness(candidates(row, :));
                [c, ceq] = nonlcon(candidates(row, :));
                violations(row) = sum(max(c(:), 0).^2) + sum(abs(ceq(:)).^2);
            catch simulation_error
                warning('wdn:CandidateFailed', 'Candidate failed: %s', simulation_error.message);
            end
            function_count = function_count + 1;
        end
    end

    function selected = tournament(candidates, values, violations)
        competitors = randi(size(candidates, 1), 1, min(3, size(candidates, 1)));
        local_order = feasible_first_order(values(competitors), violations(competitors));
        selected = candidates(competitors(local_order(1)), :);
    end

    function order = feasible_first_order(values, violations)
        feasible = violations <= options.function_tolerance;
        key_violation = violations;
        key_violation(feasible) = -1;
        key_value = values;
        key_value(~feasible) = 0;
        [~, order] = sortrows([key_violation(:), key_value(:)], [1, 2]);
    end
end
