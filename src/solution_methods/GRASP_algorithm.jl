function GRASP_algorithm(beta::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, task_times, bj, CTS)

    # it_results=Array{Tuple{Number, Number, String, String}, 1}()
    indicators = ["number", "dist"]
    sort_criteria = ["number", "dist"]
    best_makespan = CTS.H
    best_LS = init_ls(CTS)

    for iter = 1:1000
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)
        ind = indicators[rand(1:2)]
        crit = sort_criteria[rand(1:2)]

        it_time = @elapsed while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic(ind, crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC, CTS)
        end

        if check_solution(prec, LS, CTS) == true
            makespan = total_makespan(LS, CTS)
            # push!(it_results, (makespan, it_time, ind, crit))
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
            end
        end
    end
    # return(it_results, best_makespan, best_LS)
    return(best_makespan, best_LS)
end
