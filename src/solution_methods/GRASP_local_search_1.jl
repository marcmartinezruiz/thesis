function GRASP_local_search(beta::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, task_times, bj, CTS)
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    for iter = 1:10000
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic("dist", "dist", tasks_by_w, prec, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC, CTS);
        end

        if check_solution(prec, LS, CTS) == true
            makespan = total_makespan(LS, CTS)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
            end

            #perform local_search
            gamma = rand(35:5:95)/100
            for ind in ["number", "minimal"]
                new_LS = remove_tasks(1-gamma, LS, CTS)
                println(gamma)
                check, TIME, QC = get_current_state(new_LS, CTS)
                while new_LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
                    cranes_status = "idle"
                    while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                        cranes_status = deterministicConstructionHeuristic(ind, "dist", tasks_by_w, prec, bj, new_LS, TIME, QC, CTS)
                    end
                    next_time_period(TIME, QC, CTS);
                end

                if check_solution(prec, new_LS, CTS) == true
                    makespan = total_makespan(new_LS, CTS)
                    if makespan < best_makespan
                        best_makespan = makespan
                        best_LS = deepcopy(new_LS)
                    end
                else
                    println("STOP")
                    global wrong_LS = deepcopy(new_LS)
                    return(total_makespan(LS, CTS), LS)
                    break
                end
            end

        else
            continue
        end
    end

    return(best_makespan, best_LS)
end
