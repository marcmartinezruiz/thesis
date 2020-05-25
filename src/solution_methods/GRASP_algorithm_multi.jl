function GRASP_single_thread(tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, CTS::Constants)
    #it_results=Array{Tuple{Number, Number, String, String}, 1}()
    indicators = ["number", "dist"]
    sort_criteria = ["number", "dist"]
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    max_it = 0
    no_imp_it = 0

    #for iter = 1:125
    while max_it < 1250 || no_imp_it < 125
        max_it += 1
        makespan = CTS.H
        LS = init_ls(CTS)
        QC = init_qc(CTS)
        TIME = init_timer(CTS)
        ind = indicators[rand(1:2)]
        crit = sort_criteria[rand(1:2)]

        #it_time = @elapsed while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
        while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
            cranes_status = "idle"
            while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                cranes_status = randomizedConstructionHeuristic(ind, crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
            end
            next_time_period(TIME, QC, CTS)
        end

        if check_solution(prec, LS, CTS) == true
            makespan = total_makespan(LS, CTS)
            if makespan < best_makespan
                best_makespan = makespan
                best_LS = deepcopy(LS)
                no_imp_it = 0
            else
                no_imp_it += 1
            end
        end
    end

    return((best_makespan, best_LS))
end

function GRASP_multi_thread(beta::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, task_times, bj, CTS)
    best_makespan = CTS.H
    best_LS = init_ls(CTS)

    results = Dict{Int, Tuple{Int, LoadingSequence}}()
    s1 = @spawnat 2 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s2 = @spawnat 3 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s3 = @spawnat 4 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s4 = @spawnat 5 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s5 = @spawnat 6 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s6 = @spawnat 7 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    s7 = @spawnat 8 GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    r = GRASP_single_thread(tasks_by_w, prec, bj, CTS)
    wait(s1)
    wait(s2)
    wait(s3)
    wait(s4)
    wait(s5)
    wait(s6)
    wait(s7)

    # 8 Threads
    if s1[1]<=r[1] && s1[1]<=s2[1] && s1[1]<=s3[1] && s1[1]<=s4[1] && s1[1]<=s5[1] && s1[1]<=s6[1] && s1[1]<=s7[1]
        return(s1[1],s1[2])
    elseif s2[1]<=r[1] && s2[1]<=s1[1] && s2[1]<=s3[1] && s2[1]<=s4[1] && s2[1]<=s5[1] && s2[1]<=s6[1] && s2[1]<=s7[1]
        return(s2[1],s2[2])
    elseif s3[1]<=r[1] && s3[1]<=s1[1] && s3[1]<=s2[1] && s3[1]<=s4[1] && s3[1]<=s5[1] && s3[1]<=s6[1] && s3[1]<=s7[1]
        return(s3[1],s3[2])
    elseif s4[1]<=r[1] && s4[1]<=s1[1] && s4[1]<=s2[1] && s4[1]<=s3[1] && s4[1]<=s5[1] && s4[1]<=s6[1] && s4[1]<=s7[1]
        return(s4[1],s4[2])
    elseif s5[1]<=r[1] && s5[1]<=s1[1] && s5[1]<=s2[1] && s5[1]<=s3[1] && s5[1]<=s4[1] && s5[1]<=s6[1] && s5[1]<=s7[1]
        return(s5[1],s5[2])
    elseif s6[1]<=r[1] && s6[1]<=s1[1] && s6[1]<=s2[1] && s6[1]<=s3[1] && s6[1]<=s4[1] && s6[1]<=s5[1] && s6[1]<=s7[1]
        return(s6[1],s6[2])
    elseif s7[1]<=r[1] && s7[1]<=s1[1] && s7[1]<=s2[1] && s7[1]<=s3[1] && s7[1]<=s4[1] && s7[1]<=s5[1] && s7[1]<=s6[1]
        return(s7[1],s7[2])
    else
        return(r[1],r[2])
    end

    # 4 Threads
    # if s1[1]<=r[1] && s1[1]<=s2[1] && s1[1]<=s3[1]
    #     return(s1[1],s1[2])
    # elseif s2[1]<=r[1] && s2[1]<=s1[1] && s2[1]<=s3[1]
    #     return(s1[1],s1[2])
    # elseif s3[1]<=r[1] && s3[1]<=s1[1] && s3[1]<=s2[1]
    #     return(s1[1],s1[2])
    # else
    #     return(r[1],r[2])
    # end

    # 2 Threads
    # if s1[1]<=r[1]
    #     return(s1[1],s1[2])
    # else
    #     return(r[1],r[2])
    # end

    return(best_makespan, best_LS)
end
