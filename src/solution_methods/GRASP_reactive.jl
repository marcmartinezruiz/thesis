using JuMP, Gurobi, Statistics, StatsBase
include("../basics/main.jl")
include("../basics/validations.jl")
include("../JuMP/JuMP_models.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")

function reactive_GRASP(CTS::Constants)
    tasks_by_w = OperationalShippingProblem(0, CTS)
    indicators = ["minimal", "maximal", "dist"]
    weights = [1/3, 1/3, 1/3]
    ind_results = Dict{String, Tuple{Float64, Int}}()
    for i in indicators
        ind_results[i] = (0,0)
    end

    worst_makespan = 0
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    for iter = 1:1000
        #init Loading Sequence and Quay Cranes
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        #update indicator probabilities
        if iter%500 == 0
            sum_inv = 0
            for (key, value) in ind_results
                sum_inv += ((value[1]-worst_makespan)/(best_makespan-worst_makespan))^2
            end
            for i = 1:3
                weights[i] = ((ind_results[indicators[i]][1]-worst_makespan)/(best_makespan-worst_makespan))^2/sum_inv
            end
        println(indicators)
        println(weights)
        end

        #choose indicator
        ind_name = sample(indicators, Weights(weights))

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic(ind_name, tasks_by_w, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC);
        end

        if check_solution(LS, QC, CTS) == true
            makespan = total_makespan(LS, CTS)
            ind_results[ind_name] = ((ind_results[ind_name][1]*ind_results[ind_name][end]+makespan)/(ind_results[ind_name][end]+1), ind_results[ind_name][end]+1)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
            elseif makespan > worst_makespan
            worst_makespan = makespan
            end
        end
    end

    return(best_makespan, best_LS)
end

best_makespan, best_LS = reactive_GRASP(CTS)
plot_solution(best_LS, best_makespan, CTS)
