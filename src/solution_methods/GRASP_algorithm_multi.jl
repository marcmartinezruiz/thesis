function GRASP_single_thread(tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, CTS::Constants)
    #it_results=Array{Tuple{Number, Number, String, String}, 1}()
    LS = init_ls(CTS)
    QC = init_qc(CTS)
    TIME = init_timer(CTS)
    ind = ["number", "dist"][rand(1:2)]
    crit = ["number", "dist"][rand(1:2)]

    #it_time = @elapsed while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
    while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
        cranes_status = "idle"
        while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
            cranes_status = randomizedConstructionHeuristic(ind, crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
        end
        next_time_period(TIME, QC, CTS)
    end

    if check_solution(prec, LS, CTS) == true
        return((total_makespan(LS, CTS), LS))
    else
        return((CTS.H, 0))
    end
end

function GRASP_multi_thread(beta::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, task_times, bj, CTS)
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    iter = 0
    no_imp_it = 0

    while iter < 15000 && no_imp_it < 1000
        s1 = @spawnat 2 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s2 = @spawnat 3 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s3 = @spawnat 4 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s4 = @spawnat 5 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s5 = @spawnat 6 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s6 = @spawnat 7 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        s7 = @spawnat 8 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        r = GRASP_single_thread(tasks_by_w, prec, bj, CTS)
        iter += 8
        wait(s1)
        if s1[1] < best_makespan
            best_makespan = s1[1]
            best_LS = deepcopy(s1[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s2)
        if s2[1] < best_makespan
            best_makespan = s2[1]
            best_LS = deepcopy(s2[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s3)
        if s3[1] < best_makespan
            best_makespan = s3[1]
            best_LS = deepcopy(s3[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s4)
        if s4[1] < best_makespan
            best_makespan = s4[1]
            best_LS = deepcopy(s4[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s5)
        if s5[1] < best_makespan
            best_makespan = s5[1]
            best_LS = deepcopy(s5[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s6)
        if s6[1] < best_makespan
            best_makespan = s6[1]
            best_LS = deepcopy(s6[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
        wait(s7)
        if s7[1] < best_makespan
            best_makespan = s7[1]
            best_LS = deepcopy(s7[2])
            no_imp_it = 0
        else
            no_imp_it += 1
        end
    end

    return(best_makespan, best_LS)
end
