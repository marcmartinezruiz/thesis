function horizon_plan(C::Int, P::Int, J::Int, Q::Int, tt::Int, delta::Int, tasks_by_position::Dict{Int, Array{Task, 1}})
    H=tt*C*(J-1-(delta+1)*(Q-1))
    #H=tt*C*(J-1)
    for (key, value) in tasks_by_position
        h=0
        for t in value
            if t.t > h
                h=2*t.t
            end
        end
        H=H+h
    end
    return(H)
end

function subset_pos(dummy::Array, set::Array{Int, 2}, pos_cont::Int)
    sub_set = findall(x->x!=0, set[pos_cont,:])
    return(sub_set)
end

function subset_pos_cont(set::Array, pos_cont::Int)
    sub_set = findall(x->x!=0, set[pos_cont,:])
    return(sub_set)
end

function subset_bay(CTS::Constants, q::Int)
    sub_set = collect((q-1)*(CTS.delta+1)+1:CTS.J-(CTS.Q-q)*(CTS.delta+1))
    return(sub_set)
end

function bay_to_pos(bay::Int, bj::Array{Int, 1})
    l = Array{Int, 1}()
    for p = 1:length(bj)
        if bj[p] == bay
            push!(l, p)
        end
    end
    return(l)
end

function subset_pos_crane(CTS::Constants, q::Int, bj::Array{Int, 1})
    available_bays = subset_bay(CTS, q)
    sub_set = Array{Int, 1}()
    for bay in available_bays
        append!(sub_set, bay_to_pos(bay, bj))
    end
    return(sub_set)
end

function subset_crane_pos(CTS::Constants, p::Int, bj::Array{Int, 1})
    sub_set = Array{Int, 1}()
    for q = 1:Q
        if p in subset_pos_crane(CTS, q, bj)
            push!(sub_set, q)
        end
    end
    return(sub_set)
end
