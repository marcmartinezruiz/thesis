function GRASP_algorithm(beta::Number, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, CTS)

    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    w = init_ls(CTS)
    for iter = 1:100
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)

        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic("number", tasks_by_w, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC);
        end

        if check_solution(LS, CTS) == true
            makespan = total_makespan(LS, CTS)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
            end
        else
            w_LS = deepcopy(LS)
            return(0, w_LS)
        end
    end
    return(best_makespan, best_LS)
end
