struct Task
    p::Int
    c::Int
    t::Int
end

mutable struct QuayCrane
    q::Int
    busy::Bool
    work_load::Int
    p::Array{Int, 1}
end

mutable struct LoadingSequence
    order::Array{Task, 1}
    P::Int
    len::Int
    tasks_left::Int
    filled::Array{Int, 1}
    loaded::Array{Int, 1}
end


function horizon_plan(J::Int, C::Int, Q::Int, delta::Int, tt::Int, tasks_by_pos::Dict)
    H=tt*C*(J-1-(delta+1)*(Q-1))
    print("H0 = "); print(H)
    for (key, value) in tasks_by_position
        h=0
        for t in value
            if t.t > h
                h=t.t
            end
        end
        H=H+h
    end
    return(H)
end


function init_ls(P::Int)
    LS = LoadingSequence([], P, 0, P, m, m)
    return(LS)
end


function init_qc(P::Int, Q::Int, qj::Array )
    QC=[]
    for q = 1:Q
        qc_pos=[]
        for j = 1:P
            if qj[j,q]==1
                push!(qc_pos, j)
            end
        end
        push!(QC, QuayCrane(q, false, 0, qc_pos))
    end
    return(QC)
end