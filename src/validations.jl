function check_prec(LS::LoadingSequence, task::Task, precedences::Dict)
    for req in precedences[task.p]
        if !(req in LS.filled_pos)
            print("trying to add position, but still missing")
            print(setdiff(precedences[task.p],LS.filled_pos))
            return(false)
        end
    end
    return(true)
end

#check clearance to know if a QC can go to a certain bay
function check_clearance(QC::Array{QuayCrane, 1}, q::Int, target_bay::Int, CTS::Constants)
    if QC[q-1].current_bay < target_bay - CTS.delta && QC[q+1].current_bay > target_bay + CTS.delta
        return(true)
    end
    return(false)
end
#no clearance but not busy -> by moving both cranes -> problem solved
    # elseif QC[q-1].current_bay < target_bay - delta && QC[q-1].status == idle
    #     if check_clearance(QC, q-1, target_bay - delta - 1, delta) == true
    #         ...
    #     end
    # elseif QC[q+1].current_bay > target_bay + delta && QC[q+1].status == idle
    #     if check_clearance(QC, q+1, target_bay + delta + 1, delta) == true
    #         ...
    #     end
#     end
#     return(false)
# end


#check if all positions/containers are filled/loaded without repetitions
function check_tasks(LS::LoadingSequence, CTS::Constants)
    if length(LS.filled_pos) == P && length(LS.loaded_cont) == C && length(setdiff(LS.filled_pos, collect(1:P))) == 0 && length(setdiff(LS.loaded_cont, collect(1:C))) == 0
        return(true)
    else
        return(false)
    end
end

#get QC moves and times
function get_qc_moves(LS::LoadingSequence, CTS::Constants)
    QC_MOVES=Dict{Int, Array{Tuple, 1}}()
    for q = 1:CTS.Q
        l=[]
        for t in LS.order
            if t.qc == q
                push!(l, (bay=t.task.b, start_time=t.start_time, time=t.task.t))
            end
        end
        QC_MOVES[q]=l
    end
    return(QC_MOVES)
end

function check_solution(LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    #check positions and containers
    if check_tasks(LS, CTS) == false
        return(false)
    end

    #check the QC constraints
    QC_MOVES=get_qc_moves(LS, CTS)

    for clock in 1:CTS.H
        current_cranes=[]
        for (key, value) in QC_MOVES
            if clock == 1
                for i = 1: length(value)-1
                    #check loading + travel time
                    if value[i].start_time + value[i].time + travel_time(value[i].bay, value[i+1].bay, CTS) > value[i].start_time
                        return(false)
                    end
                    #check that cranes respect bays
                    if !(value[i].b in QC[key].available_bays)
                        return(false)
                    end
                end
                if !(value[length(value)].b in QC[key].available_bays)
                    return(false)
                end
            end

            #s'hauria de millorar per si una grua te idle time
            for tuple in value
                if tuple.start_time <= clock && clock <= tuple.start_time + tuple.time
                    push!(current_cranes, (key, tuple.b))
                end
            end
        end

        #check clearance
        sort(current_cranes, by = first)
        for b = 1:length(current_cranes)-1
            if current_cranes[b] - current_cranes[b+1] < CTS.delta
                return(false)
            end
        end
    end
end

using Gadfly
function plot_solution(LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    QC_MOVES=get_qc_moves(LS, QC, CTS)
    # # QC_MOVES=Dict{Int, Array{NamedTuple{(:bay, :start_time, :time),Tuple{Int64,Int64,Int64}}, 1}}()
    # QC_MOVES[1]=[(bay=1,start_time=1,time=3), (bay=1,start_time=4,time=2), (bay=2,start_time=7,time=3)]
    # QC_MOVES[2]=[(bay=3,start_time=1,time=5), (bay=4,start_time=7,time=4)]

    list_df=[]
    for n=1:CTS.Q
        push!(list_df, DataFrame(Bay = [x[1] for x in QC_MOVES[n]], Start = [x[2] for x in QC_MOVES[n]], Time = [x[2]+x[3] for x in QC_MOVES[n]], var = map(i -> "Quay Crane " * string(i), n)))
    end
    df=vcat(list_df...)

    plot(df, x = :Start, xend = :Time, y = :Bay, yend = :Bay, color = :var, Geom.segment( filled=false), Theme(line_width=1cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
               major_label_font_size=16pt,minor_label_font_size=14pt))
end
