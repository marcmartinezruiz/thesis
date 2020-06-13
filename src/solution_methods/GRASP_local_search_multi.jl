function GRASP_single_thread(weights::Array{Float64, 1}, tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, CTS::Constants)
    #it_results=Array{Tuple{Number, Number, String, String}, 1}()
    LS = init_ls(CTS)
    QC = init_qc(CTS)
    TIME = init_timer(CTS)
    crit = sample(["number", "dist"], Weights(weights))

    #it_time = @elapsed while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
    while LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
        cranes_status = "idle"
        while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
            cranes_status = randomizedConstructionHeuristic("dist", crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
        end
        next_time_period(TIME, QC, CTS)
    end

    if check_solution(prec, LS, CTS) == true
        makespan = total_makespan(LS, CTS)
        best_LS = deepcopy(LS)
        best_makespan = makespan
        #perform local_search_1
        gamma = rand(35:5:95)/100
        for ind in ["number", "minimal"]
            new_LS = remove_tasks(1-gamma, LS, CTS)
            check, TIME, QC = get_current_state(new_LS, CTS)
            while new_LS.tasks_left > 0 && TIME.period < TIME.horizon_plan
                cranes_status = "idle"
                while cranes_status != "All cranes are busy" && cranes_status != "Next time period" && cranes_status != "LS is completed"
                    cranes_status = deterministicConstructionHeuristic(ind, crit, tasks_by_w, prec, bj, new_LS, TIME, QC, CTS)
                end
                next_time_period(TIME, QC, CTS);
            end

            if check_solution(prec, new_LS, CTS) == true
                new_makespan = total_makespan(new_LS, CTS)
                if new_makespan < makespan
                    best_LS = deepcopy(new_LS)
                    best_makespan = new_makespan
                end
            else
                break
            end
        end

        #perform local_search_2
        r = remove_single_moves(prec, best_makespan, best_LS, CTS)
        remove_useless_travel(r)
        return((total_makespan(r, CTS), r, crit))
        # return((r[1], r[2], crit))
    else
        return((CTS.H, 0, crit))
    end
end

function GRASP_multi_thread(beta::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    tasks_by_w = OperationalShippingProblem(beta, task_times, bj, CTS)
    worst_makespan = 0
    best_makespan = CTS.H
    best_LS = init_ls(CTS)
    iter = 0
    no_imp_it = 0
    #reactive weights
    weights = [0.5, 0.5]
    sort_crit = ["number", "dist"]
    crit_results = Dict{String, Tuple{Number, Int}}()
    for i in sort_crit
        crit_results[i] = (0,0)
    end

    while iter < 20000 && no_imp_it < 2000
        #update indicator probabilities
        if iter%500 == 0
            sum_inv = 0
            for (key, value) in crit_results
                sum_inv += ((value[1]-worst_makespan)/(best_makespan-worst_makespan))^2
            end
            if sum_inv != 0
                for i = 1:2
                    weights[i] = ((crit_results[sort_crit[i]][1]-worst_makespan)/(best_makespan-worst_makespan))^2/sum_inv
                end
            end
        end

        s1 = @spawnat 2 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s2 = @spawnat 3 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s3 = @spawnat 4 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s4 = @spawnat 5 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s5 = @spawnat 6 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s6 = @spawnat 7 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        s7 = @spawnat 8 GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        r = GRASP_single_thread(weights, tasks_by_w, prec, bj, CTS)
        iter += 8
        wait(s1)
        crit_results[s1[3]] = ((crit_results[s1[3]][1]*crit_results[s1[3]][end]+s1[1])/(crit_results[s1[3]][end]+1), crit_results[s1[3]][end]+1)
        if s1[1] < best_makespan
            best_makespan = s1[1]
            best_LS = deepcopy(s1[2])
            no_imp_it = 0
        elseif s1[1] > worst_makespan
            worst_makespan = s1[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s2)
        crit_results[s2[3]] = ((crit_results[s2[3]][1]*crit_results[s2[3]][end]+s2[1])/(crit_results[s2[3]][end]+1), crit_results[s2[3]][end]+1)
        if s2[1] < best_makespan
            best_makespan = s2[1]
            best_LS = deepcopy(s2[2])
            no_imp_it = 0
        elseif s2[1] > worst_makespan
            worst_makespan = s2[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s3)
        crit_results[s3[3]] = ((crit_results[s3[3]][1]*crit_results[s3[3]][end]+s3[1])/(crit_results[s3[3]][end]+1), crit_results[s3[3]][end]+1)
        if s3[1] < best_makespan
            best_makespan = s3[1]
            best_LS = deepcopy(s3[2])
            no_imp_it = 0
        elseif s3[1] > worst_makespan
            worst_makespan = s3[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s4)
        crit_results[s4[3]] = ((crit_results[s4[3]][1]*crit_results[s4[3]][end]+s4[1])/(crit_results[s4[3]][end]+1), crit_results[s4[3]][end]+1)
        if s4[1] < best_makespan
            best_makespan = s4[1]
            best_LS = deepcopy(s4[2])
            no_imp_it = 0
        elseif s4[1] > worst_makespan
            worst_makespan = s4[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s5)
        crit_results[s5[3]] = ((crit_results[s5[3]][1]*crit_results[s5[3]][end]+s5[1])/(crit_results[s5[3]][end]+1), crit_results[s5[3]][end]+1)
        if s5[1] < best_makespan
            best_makespan = s5[1]
            best_LS = deepcopy(s5[2])
            no_imp_it = 0
        elseif s5[1] > worst_makespan
            worst_makespan = s5[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s6)
        crit_results[s6[3]] = ((crit_results[s6[3]][1]*crit_results[s6[3]][end]+s6[1])/(crit_results[s6[3]][end]+1), crit_results[s6[3]][end]+1)
        if s6[1] < best_makespan
            best_makespan = s6[1]
            best_LS = deepcopy(s6[2])
            no_imp_it = 0
        elseif s6[1] > worst_makespan
            worst_makespan = s6[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        wait(s7)
        crit_results[s7[3]] = ((crit_results[s7[3]][1]*crit_results[s7[3]][end]+s7[1])/(crit_results[s7[3]][end]+1), crit_results[s7[3]][end]+1)
        if s7[1] < best_makespan
            best_makespan = s7[1]
            best_LS = deepcopy(s7[2])
            no_imp_it = 0
        elseif s7[1] > worst_makespan
            worst_makespan = s7[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
        crit_results[r[3]] = ((crit_results[r[3]][1]*crit_results[r[3]][end]+r[1])/(crit_results[r[3]][end]+1), crit_results[r[3]][end]+1)
        if r[1] < best_makespan
            best_makespan = r[1]
            best_LS = deepcopy(r[2])
            no_imp_it = 0
        elseif r[1] > worst_makespan
            worst_makespan = r[1]
            no_imp_it += 1
        else
            no_imp_it += 1
        end
    end

    return(best_makespan, best_LS)
end
