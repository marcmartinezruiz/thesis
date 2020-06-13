function ConstructionHeuristic(order::Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}, crit::String, tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    for tuple in order
        target_bay = tuple.j
        #select a task within the target_bay
        for p in bay_to_pos(target_bay, bj)
            if check_prec(LS, tasks_by_w[p], prec) == true
                if check_loaded_filled(LS, tasks_by_w[p]) == true
                    target_task = tasks_by_w[p]
                    #check if any crane that can perform for this task
                    available_cranes=Array{Tuple{Int, Number}, 1}()
                    for q in TIME.available_cranes
                        #randomly select the cranes based on travel time
                        if target_task.b in QC[q].available_bays
                            if (target_task.b-QC[q].current_bay) == 0
                                available_cranes = [(q, 1)]
                                break
                            else
                                if crit == "dist"
                                    push!(available_cranes, (q, (abs(target_task.b-QC[q].current_bay)^2)/CTS.J*rand()))
                                else
                                    push!(available_cranes, (q, (abs(target_task.b-init_bay(q, CTS)^2)*rand())))
                                end
                                #push!(available_cranes, (q, (abs(target_task.b-QC[q].current_bay)^2)/CTS.J))
                                #push!(available_cranes, (q, (abs(target_task.b-init_bay(q, CTS)^2))))
                            end
                        end
                    end
                    if length(available_cranes) == 0
                        break
                    end

                    #try to add task if there are no clearance problems
                    for q in sort(available_cranes, by=last)
                        if check_clearance(QC, q[1], target_bay, CTS) == true && length(QC[q[1]].task_buffer) == 0
                            add_task(target_task, q[1], TIME, LS, QC, CTS)
                            return("New task successfuly added. \n---------------")
                        end
                    end

                    for q in available_cranes
                        (check, move_q, move_bay, move_status) = check_double_clearance(QC, q[1], target_bay, CTS)
                        if  check == true && length(QC[q[1]].task_buffer) == 0
                            add_task_move(target_task, q[1], move_q, move_bay, move_status, LS, TIME, QC, CTS)
                            return("New task + neighbour move successfuly added. \n---------------")
                        end
                    end

                    for q in available_cranes
                        (check, move_q, move_bay, move_q2, move_bay2) = check_triple_clearance(QC, q[1], target_bay, CTS)
                        if  check == true && length(QC[q[1]].task_buffer) == 0
                            add_move(move_q2, move_bay2, LS, TIME, QC, CTS)
                            add_task_move(target_task, q[1], move_q, move_bay, "idle", LS, TIME, QC, CTS)
                            return("New task + neighbour move successfuly added. \n---------------")
                        end
                    end
                end
            end
        end
    end
    for q in QC
        if q.status != "idle"
            return("Next time period")
        end
    end
    if CTS.Q >= 4
        stucked_bays(order, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
    end
    return("Next time period")
end

function randomizedConstructionHeuristic(ind::String, crit::String, tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    #check if all cranes are busy
    if length(TIME.available_cranes) == 0
        return("All cranes are busy")
    end
    #check if LS is completed
    if LS.tasks_left == 0
        return("LS is completed")
    end

    #order according to indicator
    work_load = order_by_maximal_bay(false, tasks_by_w, bj, LS, CTS)
    if ind == "dist"
        order = order_by_dist(true, work_load, QC, CTS)
    elseif ind == "number"
        work_load_dist = order_by_dist(false, work_load, QC, CTS)
        order = order_by_number(true, work_load_dist, QC, CTS)
    end

    output = ConstructionHeuristic(order, crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
    return(output)
end

function deterministicConstructionHeuristic(ind::String, crit::String, tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    #check if all cranes are busy
    if length(TIME.available_cranes) == 0
        return("All cranes are busy")
    end
    #check if LS is completed
    if LS.tasks_left == 0
        return("LS is completed")
    end

    #order according to indicator
    work_load = order_by_maximal_bay(false, tasks_by_w, bj, LS, CTS)
    if ind == "minimal"
        order = reverse!(work_load)
    elseif ind == "number"
        work_load_dist = order_by_dist(false, work_load, QC, CTS)
        order = order_by_number(false, work_load_dist, QC, CTS)
    end

    output = ConstructionHeuristic(order, crit, tasks_by_w, prec, bj, LS, TIME, QC, CTS)
    return(output)
end



function stucked_bays(order::Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}, tasks_by_w::Dict{Int, LTask}, prec::Dict{Int, Array}, bj::Array{Int, 1}, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    if LS.tasks_left != 0
        for tuple in order
            target_bay = tuple.j
            #select a task within the target_bay
            for p in bay_to_pos(target_bay, bj)
                if check_prec(LS, tasks_by_w[p], prec) == true
                    if check_loaded_filled(LS, tasks_by_w[p]) == true
                        target_task = tasks_by_w[p]
                        #check if any crane that can perform for this task
                        if target_bay in QC[1].available_bays && 1 in TIME.available_cranes
                            add_move(3, target_bay + CTS.delta + 3, LS, TIME, QC, CTS)
                            add_move(4, target_bay + CTS.delta + 5, LS, TIME, QC, CTS)
                            add_task_move(target_task, 1, 2, target_bay + CTS.delta + 1, "idle", LS, TIME, QC, CTS)
                            return("New task successfuly added. \n---------------")
                        elseif target_bay in QC[CTS.Q].available_bays && CTS.Q in TIME.available_cranes
                            add_move(2, target_bay - CTS.delta - 3, LS, TIME, QC, CTS)
                            add_move(1, target_bay - CTS.delta - 5, LS, TIME, QC, CTS)
                            add_task_move(target_task, 4, 3, target_bay - CTS.delta - 1, "idle", LS, TIME, QC, CTS)
                            return("New task successfuly added. \n---------------")
                        end
                    end
                end
            end
        end
        return("Next time period")
    else
        return("LS is completed")
    end
end
