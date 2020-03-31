
#get QC moves and times
function get_qc_moves(LS::LoadingSequence, CTS::Constants)
    QC_MOVES=Dict{Int, Array{NamedTuple{(:bay, :start_time, :time),Tuple{Int64,Int64,Int64}}, 1}}()
    for q = 1:CTS.Q
        l=Array{NamedTuple{(:bay, :start_time, :time),Tuple{Int64,Int64,Int64}}, 1}()
        for t in LS.order
            if t.qc == q
                push!(l, (bay=t.task.b, start_time=t.start_time, time=t.task.t))
            end
        end
        QC_MOVES[q]=l
    end
    return(QC_MOVES)
end

#get QC travel times
function get_qc_travel(QC_MOVES::Dict{Int, Array{NamedTuple{(:bay, :start_time, :time),Tuple{Int64,Int64,Int64}}, 1}}, CTS::Constants)
    QC_TRAVEL=Dict{Int, Array{NamedTuple{(:start_bay, :end_bay, :start_time, :end_time),Tuple{Int64,Int64,Int64,Int64}}, 1}}()
    for q = 1:CTS.Q
        l=Array{NamedTuple{(:start_bay, :end_bay, :start_time, :end_time),Tuple{Int64,Int64,Int64,Int64}}, 1}()
        for t = 1:length(QC_MOVES[q])-1
            if QC_MOVES[q][t].bay != QC_MOVES[q][t+1].bay
                start_time = QC_MOVES[q][t].start_time + 2*QC_MOVES[q][t].time
                end_time = QC_MOVES[q][t+1].start_time
                start_bay = QC_MOVES[q][t].bay
                end_bay = QC_MOVES[q][t+1].bay
                if end_time - start_time <= abs(start_bay - end_bay)*CTS.tt
                    push!(l, (start_bay = start_bay, end_bay = end_bay, start_time = start_time, end_time = end_time))
                else
                    push!(l, (start_bay = start_bay, end_bay = start_bay, start_time = start_time, end_time=end_time - abs(start_bay - end_bay)*CTS.tt))
                    push!(l, (start_bay = start_bay, end_bay = end_bay, start_time = end_time - abs(start_bay - end_bay)*CTS.tt, end_time = end_time))
                end
            end
        end
        QC_TRAVEL[q]=l
    end
    return(QC_TRAVEL)
end



#check position precedences
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

#check if all positions/containers are filled/loaded without repetitions
function check_tasks(LS::LoadingSequence, CTS::Constants)
    if length(LS.filled_pos) == P && length(LS.loaded_cont) == C && length(setdiff(LS.filled_pos, collect(1:P))) == 0 && length(setdiff(LS.loaded_cont, collect(1:C))) == 0
        return(true)
    else
        return(false)
    end
end

#check clearance to know if a QC can go to a certain bay
function check_clearance(QC::Array{QuayCrane, 1}, q::Int, target_bay::Int, CTS::Constants)
    if QC[q-1].current_bay < target_bay - CTS.delta && QC[q+1].current_bay > target_bay + CTS.delta
        return(true)
    end
    return(false)
end

#check if a solution is correct
function check_solution(LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    #check positions and containers
    if check_tasks(LS, CTS) == false
        return(false)
    end

    #check precedences are followed
    for task in LS.order
        if task[1].p != 0
            if check_prec(LS,task[1],prec) == false
                return(false)
            end
        end
    end

    #check the QC constraints
    QC_MOVES=get_qc_moves(LS, CTS)
    for clock in 1:CTS.H
        current_cranes=Array{Tuple{Int, Int}, 1}()
        for (key, value) in QC_MOVES
            if clock == 1
                for i = 1: length(value)-1
                    #check loading + travel time
                    if value[i].start_time + 2*value[i].time + travel_time(value[i].bay, value[i+1].bay, CTS) > value[i+1].start_time
                        print("wrong task/travel time")
                        return(false)
                    end
                    #check that cranes respect bays
                    if !(value[i].bay in QC[key].available_bays)
                        print("wrong bays")
                        return(false)
                    end
                end
                if !(value[length(value)].bay in QC[key].available_bays)
                    print("wrong bays")
                    return(false)
                end
            end

            #s'hauria de millorar per si una grua te idle time
            for tuple in value
                if tuple.start_time <= clock && clock <= tuple.start_time + tuple.time
                    push!(current_cranes, (key, tuple.bay))
                end
            end
        end

        #check clearance
        sort(current_cranes, by = first)
        for b = 1:length(current_cranes)-1
            if current_cranes[b][1] - current_cranes[b+1][1] < CTS.delta
                print("wrong clearance")
                return(false)
            end
        end
    end
    return(true)
end


#plot the solution
using Gadfly
using DataFrames
Gadfly.set_default_plot_size(25cm, 10cm)
function plot_solution(LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    QC_MOVES=get_qc_moves(LS, CTS)
    QC_TRAVEL=get_qc_travel(QC_MOVES, CTS)

    list_moves=[]
    list_travel=[]
    for n=1:CTS.Q
        push!(list_moves, DataFrame(Bay = [x.bay for x in QC_MOVES[n]], Start = [x.start_time for x in QC_MOVES[n]], End = [x.start_time+2*x.time for x in QC_MOVES[n]], var = map(i -> "Quay Crane " * string(i), n)))
        push!(list_travel, DataFrame(start_bay = [x.start_bay for x in QC_TRAVEL[n]], end_bay = [x.end_bay for x in QC_TRAVEL[n]], start_time = [x.start_time for x in QC_TRAVEL[n]], end_time = [x.end_time for x in QC_TRAVEL[n]], var = map(i -> "Quay Crane " * string(i), n)))
    end
    df_moves=vcat(list_moves...)
    df_travel=vcat(list_travel...)

    #plot scale
    xsc  = Scale.x_continuous(minvalue=0, maxvalue=makespan)
    ysc  = Scale.y_continuous(minvalue=0, maxvalue=CTS.J+1)
    #plot(df, x = :Start, xend = :Time, y = :Bay, yend = :Bay, color = :var, Geom.segment(filled=false), Theme(line_width=1cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
          #     major_label_font_size=16pt,minor_label_font_size=14pt), xsc, ysc)

    layer1 = layer(df_moves, x = :Start, xend = :End, y = :Bay, yend = :Bay, color = :var, Geom.segment(filled=false), Theme(alphas=[0.5], line_width=1cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
               major_label_font_size=16pt,minor_label_font_size=14pt))
    layer2 = layer(df_travel, x = :start_time, xend = :end_time, y = :start_bay, yend = :end_bay, color = :var, Geom.segment(filled=false), Theme(line_style=[:dot] ,line_width=0.05cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
               major_label_font_size=16pt,minor_label_font_size=14pt))

    plot(layer1, layer2,xsc, ysc)
    
end
