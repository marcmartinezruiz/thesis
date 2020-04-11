include("../basics/basic_functions.jl")
function remaining_bay_time(j::Int, tasks_by_w::Dict{Int, Task}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
    total = 0
    count = 0
    for p = 1:CTS.P
        if bj[p] == j
            total += tasks_by_w[p].t
        end
    end
    for t in LS.order
        if t.task.b == j
            count += t.task.t
        end
    end
    return(total - count)
end

function bays_work_load(tasks_by_w::Dict{Int, Task}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
    work_load = Array{NamedTuple{(:j, :remaining_time),Tuple{Int, Int}}, 1}()
    for j = 1:CTS.J
        if remaining_bay_time(j, tasks_by_w, bj, LS, CTS) > 0
            push!(work_load, (j=j, remaining_time=remaining_bay_time(j, tasks_by_w, bj, LS, CTS)))
        end
    end
    if length(work_load) > 0
        sort!(work_load, by = x->x.remaining_time, rev=true)
    end
    return(work_load)
end

function total_remaining_time(work_load::Array{NamedTuple{(:j, :remaining_time),Tuple{Int, Int}}, 1})
    total = 0
    for bay in work_load
        total += bay.remaining_time
    end
    return(total)
end

function order_by_maximal_bay(tasks_by_w::Dict{Int, Task}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
    #calculate remaining times
    work_load = bays_work_load(tasks_by_w, bj, LS, CTS)
    total = total_remaining_time(work_load)
    #order the bays (maximal + random)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load
        push!(order, (j=bay.j, prob=(bay.remaining_time/total)*rand()))
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end

function order_by_dist(tasks_by_w::Dict{Int, Task}, bj::Array{Int, 1}, LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    #calculate remaining times
    work_load = bays_work_load(tasks_by_w, bj, LS, CTS)
    total = total_remaining_time(work_load)
    #order the bays (maximal + random)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load
        dist = 0
        i=1
        for q in QC
            if bay.j in q.available_bays || q.status == "idle"
                dist = (dist*i + abs(bay.j - q.current_bay)^2)/(i+1)
                i += 1
            end
        end

        if dist > 0
            prob = (bay.remaining_time/total)*dist*rand()
        else
            prob = (bay.remaining_time/total)*CTS.J
        end

        push!(order, (j=bay.j, prob=prob))
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end




function GRASP(ind::String, tasks_by_w::Dict{Int, Task}, bj::Array{Int, 1}, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    #check if all cranes are busy
    if length(TIME.available_cranes) == 0
        return("All cranes are busy")
    end
    #check if LS is completed
    if LS.tasks_left == 0
        return("LS is completed")
    end

    #order depending on the indicators
    if ind == "maximal"
        order = order_by_maximal_bay(tasks_by_w, bj, LS, CTS)
    elseif ind == "minimal"
        order = reverse(order_by_maximal_bay(tasks_by_w, bj, LS, CTS))
    else
        order = order_by_dist(tasks_by_w, bj, LS, QC, CTS)
    end

    for tuple in order
        target_bay = tuple.j
        #select a task within the target_bay
        for p in bay_to_pos(target_bay, bj)
            if check_prec(LS, tasks_by_w[p], prec) == true
                if check_loaded_filled(LS, tasks_by_w[p]) == true
                    target_task = tasks_by_w[p]
                    #check if any crane that can perform for this task
                    available_cranes=Array{Tuple{Int, Float64}, 1}()
                    for q in TIME.available_cranes
                        #randomly select the cranes based on travel time
                        if target_task.b in QC[q].available_bays
                            push!(available_cranes, (q, abs(target_task.b-QC[q].current_bay)/CTS.J*rand()))
                        end
                    end
                    if length(available_cranes) == 0
                        break
                    end

                    #try to add task if there are no clearance problems
                    for q in sort(available_cranes, by=last)
                        if check_clearance(QC, q[1], target_bay, CTS) == true
                            add_task(target_task, q[1], TIME, LS, QC, CTS)
                            return("New task successfuly added. \n---------------")
                        end
                    end

                    for q in available_cranes
                        (check, move_q, move_bay, move_status) = check_double_clearance(QC, q[1], target_bay, CTS)
                        if  check == true
                            add_task_move(target_task, q[1], move_q, move_bay, move_status, LS, TIME, QC, CTS)
                            return("New task + neighbour move successfuly added. \n---------------")
                        end
                    end
                end
            end
        end
    end
    return("Next time period")
end
