using JuMP, Gurobi
include("../basics/main.jl")
include("../basics/validations.jl")
include("../JuMP/JuMP_models.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")

function GRASP_final_local_search(CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, CTS)
    final_update = "false"
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    for iter = 1:1000
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = GRASP("dist", tasks_by_w, bj, LS, TIME, QC, CTS)
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
            final_LS = init_ls(CTS)
            final_makespan = CTS.H
            for iter_ls = 1:5
                min_q, moves, TIME, QC = get_final_state(best_LS, CTS)
                if moves == 2
                    break
                end
                final_LS = remove_final_tasks(moves, best_LS, CTS)
                while final_LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
                    cranes_status = "idle"
                    while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                        cranes_status = ls_final(min_q, tasks_by_w, bj, final_LS, TIME, QC, CTS)
                    end
                    next_time_period(TIME, QC);
                end

                if check_solution(final_LS, QC, CTS) == true
                    final_makespan = total_makespan(final_LS, CTS)
                    if final_makespan <= best_makespan
                        best_makespan = final_makespan
                        best_LS = deepcopy(final_LS)
                        final_update = "true"
                    end
                end
            end
        end
    end

    return(final_update, best_makespan, best_LS)
end

final_update, best_makespan, best_LS = GRASP_final_local_search(CTS)
plot_solution(best_LS, best_makespan, CTS)
