function clearance_travel_time(i::Int, j::Int, v::Int, w::Int, bj_dict::Dict{Int, Array{Int,1}}, CTS::Constants)
    delta = (CTS.delta + 1)*abs(v-w)
    li = bj_dict[i][v]
    lj = bj_dict[j][w]
    if (v < w) && (i != j) && (li > lj - delta)
        return((li - lj + delta)*CTS.tt)
    elseif (v > w) && (i != j) && (li < lj + delta)
        return((lj - li + delta)*CTS.tt)
    else
        return(0)
    end
end

function update_math_ls(LS::LoadingSequence, t::NamedTuple{(:start_time, :pos, :next_pos, :qc),Tuple{Int64,Int64,Int64,Int64}}, sol_w::Dict{Int, Int}, CTS::Constants)
    if t.pos != 0
        LS.len += 1
        LS.tasks_left -= 1
        push!(LS.filled_pos, t.pos)
        push!(LS.loaded_cont, sol_w[t.pos])
    end
    push!(LS.order, (task=LTask(t.pos, bj_dict[t.pos][t.qc], sol_w[t.pos], JuMP.value.(t_task)[t.pos]), start_time=t.start_time, qc=t.qc))
end

function get_math_ls(sol_x::Dict{Int, Array}, sol_w::Dict{Int, Int}, CTS::Constants)
    #init Loading Sequence and Quay Cranes
    LS = init_ls(CTS)
    QC = init_qc(CTS)

    #update loading sequence with model solution
    while LS.tasks_left > 0
        task = [(start_time=CTS.H+1,pos=0,next_pos=0,qc=0)]
        for q=1:Q
            if length(sol_x[q])>0 && sol_x[q][1].start_time < task[1].start_time
                task = [sol_x[q][1]]
            elseif length(sol_x[q])>0 && sol_x[q][1].start_time == task[1].start_time
                push!(task, sol_x[q][1])
            end
        end

        for t in task
            update_math_ls(LS, t, sol_w, CTS)
            if sol_x[t.qc][1] == t
                deleteat!(sol_x[t.qc], 1)
            end
        end
    end
    return(LS)
end
