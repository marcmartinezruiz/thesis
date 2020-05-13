function remaining_bay_time(j::Int, tasks_by_w::Dict{Int, LTask}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
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

function bays_work_load(tasks_by_w::Dict{Int, LTask}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
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

function order_by_maximal_bay(rand_flag::Bool, tasks_by_w::Dict{Int, LTask}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
    #calculate remaining times
    work_load = bays_work_load(tasks_by_w, bj, LS, CTS)
    total = total_remaining_time(work_load)
    #order the bays (maximal + random)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load
        if rand_flag == true
            push!(order, (j=bay.j, prob=(bay.remaining_time/total)*rand()))
        else
            push!(order, (j=bay.j, prob=(bay.remaining_time/total)))
        end
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end

function order_by_dist(rand_flag::Bool, work_load::Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}, QC::Array{QuayCrane, 1}, CTS::Constants)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load
        min_dist = CTS.J
        max_dist = 0
        i = 1
        for q in QC
            if bay.j in q.available_bays || q.status == "idle"
                dist = abs(bay.j - q.current_bay)^2
                if dist < min_dist
                    min_dist = dist
                elseif dist > max_dist
                    max_dist = dist
                end
            end
        end

        if min_dist > 0
            if rand_flag == true
                prob = (bay.prob)*(1-(min_dist/max_dist))*rand()
            else
                prob = (bay.prob)*(1-min_dist/max_dist)
            end
        else
            if rand_flag == true
                prob = (bay.prob)*CTS.J*rand()
            else
                prob = (bay.prob)*CTS.J
            end
        end

        push!(order, (j=bay.j, prob=prob))
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end

function order_by_number(rand_flag::Bool, tasks_by_w::Dict{Int, LTask}, bj::Array{Int, 1}, LS::LoadingSequence, CTS::Constants)
    #calculate remaining times
    work_load = bays_work_load(tasks_by_w, bj, LS, CTS)
    total = total_remaining_time(work_load)
    #order the bays (maximal + random)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load
        if rand_flag == true
            push!(order, (j=bay.j, prob=(bay.remaining_time/total)/abs(bay.j-CTS.J/2)rand()))
        else
            push!(order, (j=bay.j, prob=(bay.remaining_time/total)/abs(bay.j-CTS.J/2)))
        end
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end

function order_by_number(rand_flag::Bool, work_load_dist::Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}, QC::Array{QuayCrane, 1}, CTS::Constants)
    order = Array{NamedTuple{(:j, :prob),Tuple{Int, Float64}}, 1}()
    for bay in work_load_dist
        if rand_flag == true
            push!(order, (j=bay.j, prob=(bay.prob/abs(bay.j-median(1:CTS.J))*rand())))
        else
            push!(order, (j=bay.j, prob=(bay.prob/abs(bay.j-median(1:CTS.J)))))
        end
    end
    sort!(order, by = x->x.prob, rev=true)
    return(order)
end
