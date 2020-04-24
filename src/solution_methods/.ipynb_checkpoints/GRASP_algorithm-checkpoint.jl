using JuMP, Gurobi
include("../basics/main.jl")
include("../basics/validations.jl")
include("../basics/basic_functions.jl")
include("../JuMP/JuMP_models.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")

function GRASP_algorithm(CTS::Constants)
    tasks_by_w = OperationalShippingProblem(0, CTS)

    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    for iter = 1:10
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic("dist", tasks_by_w, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC);
        end

        if check_solution(LS, QC, CTS) == true
            makespan = total_makespan(LS, CTS)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
            end
        end
    end

    return(best_makespan, best_LS)
end

#best_makespan, best_LS = GRASP_algorithm(CTS)
#plot_solution(best_LS, best_makespan, CTS)
