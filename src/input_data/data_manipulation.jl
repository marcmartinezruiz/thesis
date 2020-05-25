function horizon_plan(C::Int, P::Int, J::Int, Q::Int, tt::Int, delta::Int, bj::Array{Int,1}, tasks_by_position::Dict{Int, Array{LTask, 1}})
    med = median(bj)
    H=0
    for (key, value) in tasks_by_position
        h=0
        for t in value
            if t.t > h
                h=2*t.t
            end
        end
        if bj[key] < med
            H-=2*bj[key]
        elseif bj[key] > med
            H+=2*bj[key]
        end
        H+=h
    end
    if med in bj
        H-=med
    end
    H+=minimum(bj)
    return(H)
end

function horizon_plan_new(C::Int, P::Int, J::Int, Q::Int, tt::Int, delta::Int, bj::Array{Int,1}, tasks_by_position::Dict{Int, Array{LTask, 1}})
    UB=0
    #calculate max loading time
    LT=0
    for (key, value) in tasks_by_position
        h=0
        for t in value
            if t.t > h
                h=2*t.t
            end
        end
        LT+=h
    end
    #calculate max travel time
    for it = 1:Q
        bj_dict = Dict{Int, Array{Int, 1}}()
        order=Array{Tuple{Int,Int},1}()
        for q = 1:Q
            if q == it
                push!(order, ((q-1)*(delta+1)+1, J-(Q-q)*(delta+1)))
            elseif q < it
                push!(order, ((q-1)*(delta+1)+1, q*(delta+1)))
            elseif q > it
                push!(order, (J-(Q-q)*(delta+1)-1, J-(Q-q)*(delta+1)))
            end
        end
        println(order)
        for q = 1:Q
            bj_dict[q] = bj[order[q][1]:order[q][2]]
        end

        H=0
        for (key, value) in bj_dict
            TT=0
            med = median(value)
            for p = 1:P
                if p in value && p < med
                    TT-=2*p
                elseif p in value && p >med
                    TT+=2*p
                end
            end
            if med in value
                TT-=med
            end
            TT+=minimum(value)
            if TT > H
                H = TT
            end
        end

        H+=LT
        if H > UB
            UB = H
        end
    end
    return(UB)
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
    for q = 1:CTS.Q
        if p in subset_pos_crane(CTS, q, bj)
            push!(sub_set, q)
        end
    end
    return(sub_set)
end
