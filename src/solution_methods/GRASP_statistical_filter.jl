using JuMP, Gurobi
include("../basics/main.jl")
include("../basics/validations.jl")
include("../JuMP/JuMP_models.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")

function GRASP_statistical_filter(CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, CTS)
    sol_ini = Array{Tuple{Int, Int}, 1}()
    sol_local = Array{Tuple{Int, Int}, 1}()

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
                cranes_status = randomizedConstructionHeuristic("dist", tasks_by_w, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC);
        end

        if check_solution(LS, QC, CTS) == true
            makespan = total_makespan(LS, CTS)
            push!(sol_ini, (iter, makespan))
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = LS
            end

            #perform local_search
            local_makespan = CTS.H
            for iter_ls = 1:100
                gamma = rand(0.3:0.05:0.9)
                new_LS = remove_tasks(1-gamma, LS, CTS)
                check, TIME, QC = get_current_state(new_LS, CTS)
                while new_LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
                    cranes_status = "idle"
                    while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                        cranes_status = randomizedConstructionHeuristic("minimal", tasks_by_w, bj, new_LS, TIME, QC, CTS)
                    end
                    next_time_period(TIME, QC);
                end

                if check_solution(new_LS, QC, CTS) == true
                    makespan = total_makespan(new_LS, CTS)
                    if local_makespan < best_makespan
                        best_makespan = local_makespan = makespan
                        best_LS = deepcopy(new_LS)
                    elseif makespan < local_makespan
                        local_makespan = makespan
                    end
                else
                    println("STOP")
                    return(total_makespan(new_LS, CTS), new_LS)
                end
                push!(sol_local, (iter, local_makespan))
            end

        else
            println("ERROR")
            continue
        end
    end

    sol_ratio = Array{Float64,1}()
    for i = 1:500
        push!(sol_ratio, sol_ini[i][end]/sol_local[i][end])
    end
    filter_median = median(sol_ratio)

    return(filter_median, best_makespan, best_LS)
end

final_update, best_makespan, best_LS = GRASP_statistical_filter(CTS)
plot_solution(best_LS, best_makespan, CTS)
