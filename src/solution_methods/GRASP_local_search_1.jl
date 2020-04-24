using JuMP, Gurobi
include("../basics/main.jl")
include("../basics/validations.jl")
include("../JuMP/JuMP_models.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")

function GRASP_local_search(CTS::Constants)
    tasks_by_w = OperationalShippingProblem(0, CTS)
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    for iter = 1:500
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic("maximal", tasks_by_w, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC);
        end

        if check_solution(LS, QC, CTS) == true
            makespan = total_makespan(LS, CTS)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = LS
            end

            #perform local_search
            for gamma = 0.35:0.05:0.95
                for ind in ["maximal", "minimal", "dist"]
                    new_LS = remove_tasks(1-gamma, LS, CTS)
                    check, TIME, QC = get_current_state(new_LS, CTS)
                    while new_LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
                        cranes_status = "idle"
                        while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                            cranes_status = deterministicConstructionHeuristic("minimal", tasks_by_w, bj, new_LS, TIME, QC, CTS)
                        end
                        next_time_period(TIME, QC);
                    end

                    if check_solution(new_LS, QC, CTS) == true
                        makespan = total_makespan(new_LS, CTS)
                        if makespan < best_makespan
                            best_makespan = makespan
                            best_LS = deepcopy(new_LS)
                        end
                    else
                        break
                    end
                end
            end

        else
            continue
        end
    end

    return(best_makespan, best_LS)
end

best_makespan, best_LS = GRASP_local_search(CTS)
plot_solution(best_LS, best_makespan, CTS)
