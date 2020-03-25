function linear3D_to_dict(xipq::Array{Int, 3})
    sol_x = Dict{Int, Array}()
    for i=1:C
        for p=1:P
            for q=1:Q
                if xipq[i,p,q] == 1
                    if haskey(sol_x, q) == false
                        sol_x[q] = Array{NamedTuple{(:cont, :pos),Tuple{Int64,Int64}}, 1}()
                    end
                    push!(sol_x[q], (cont=i, pos=p))
                end
            end
        end
    end
return(sol_x)
end


mutable struct LoadingSequence
    order::Array{Tuple{Task,Int,Int}, 1}
    tasks_left::Int
    len::Int
    filled_pos::Array{Int, 1}
    loaded_cont::Array{Int, 1}
end

function update_load_seq(TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, task::Task, precedences::Dict, q::Int, CTS::Constants)
    LS.len += 1
    LS.tasks_left -= 1
    start_time = travel_time(QC[q].current_bay, task.b, CTS) + TIME.period
    push!(LS.order, (task=task, start_time=start_time, quay_crane=q)
    push!(LS.filled, task.p)
    push!(LS.loaded,task.c)
end

function init_ls(CTS::Constants)
    LS = LoadingSequence([], CTS.P, 0, [], [])
    return(LS)
end
