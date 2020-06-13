function total_makespan(LS::LoadingSequence, CTS::Constants)
    makespan = 0
    flag = Array{Int,1}()
    while Set(collect(1:CTS.Q)) != Set(flag)
        for t in reverse(LS.order)
            for q = 1:CTS.Q
                if t.qc == q && !(q in flag)
                    push!(flag, q)
                    if t.start_time + 2*t.task.t > makespan
                        makespan = t.start_time + 2*t.task.t
                        break
                    end
                end
            end
        end
    end
    return(makespan)
end

#get QC moves and times
function get_qc_moves(LS::LoadingSequence, CTS::Constants)
    makespan = total_makespan(LS, CTS)
    QC_MOVES=Dict{Int, Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}}()
    for q = 1:CTS.Q
        l=Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}()
        push!(l, (bay=init_bay(q, CTS), end_time=0, start_time=0, time=0))
        for t in LS.order
            if t.qc == q
                push!(l, (bay=t.task.b, end_time=t.start_time + 2*t.task.t, start_time=t.start_time, time=t.task.t))
            end
        end
        push!(l,(bay=l[end].bay, end_time=makespan, start_time=makespan, time=0))
        QC_MOVES[q]=l
    end
    return(QC_MOVES)
end

#get QC travel times
function get_qc_travel(QC_MOVES::Dict{Int, Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}}, CTS::Constants)
    QC_TRAVEL=Dict{Int, Array{NamedTuple{(:start_bay, :end_bay, :start_time, :end_time),Tuple{Int64,Int64,Int64,Int64}}, 1}}()
    for q = 1:CTS.Q
        l=Array{NamedTuple{(:start_bay, :end_bay, :start_time, :end_time),Tuple{Int64,Int64,Int64,Int64}}, 1}()
        for t = 1:length(QC_MOVES[q])-1
            if QC_MOVES[q][t].bay != QC_MOVES[q][t+1].bay
                start_time = QC_MOVES[q][t].end_time
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
        if length(QC_MOVES[q]) > 1 && QC_MOVES[q][end].bay == QC_MOVES[q][end-1].bay
            push!(l, (start_bay = QC_MOVES[q][end].bay, end_bay = QC_MOVES[q][end-1].bay, start_time = QC_MOVES[q][end].end_time, end_time=QC_MOVES[q][end-1].end_time))
        end
        QC_TRAVEL[q]=l
    end
    return(QC_TRAVEL)
end

function check_loaded_filled(LS::LoadingSequence, task::LTask)
    if task.p in LS.filled_pos
        #println("position already filled.")
        return(false)
    elseif task.c in LS.loaded_cont
        #println("container already loaded.")
        return(false)
    else
        return(true)
    end
end

#check position precedences
function check_prec(LS::LoadingSequence, task::LTask, prec::Dict{Int, Array})
    if length(prec[task.p]) > 0
        for req in prec[task.p]
            if !(req in LS.filled_pos)
                #print("trying to add position "*string(task.p)*", but still missing positions: ")
                #print(setdiff(precedences[task.p], LS.filled_pos))
                #print("\n")
                return(false)
            end
        end
    end
    return(true)
end

#check if all positions/containers are filled/loaded without repetitions
function check_tasks(LS::LoadingSequence, CTS::Constants)
    deleteat!(LS.filled_pos, findall(x->x==0, LS.filled_pos))
    deleteat!(LS.loaded_cont, findall(x->x==0, LS.loaded_cont))
    if LS.tasks_left == 0 && length(setdiff(collect(1:CTS.P), LS.filled_pos)) == 0 && length(setdiff(collect(1:CTS.C), LS.loaded_cont)) == 0
        return(true)
    else
        return(false)
    end
end

#check clearance to know if a QC can go to a certain bay
function check_clearance(QC::Array{QuayCrane, 1}, q::Int, target_bay::Int, CTS::Constants)
    if target_bay == QC[q].current_bay
        return(true)
    end

    m=0
    if q == 1
        for n = 1:CTS.Q-1
            if (QC[q+n].next_bay - target_bay) > CTS.delta && (QC[q+n].current_bay - target_bay) > CTS.delta
                if length(QC[q+n].task_buffer) > 0
                    for t_buffer in QC[q+n].task_buffer
                        if (t_buffer.b - target_bay) <= CTS.delta
                            return(false)
                        end
                    end
                end
                m+=1
            end
        end
        if m==CTS.Q-1
            return(true)
        end
    elseif q == CTS.Q
        for n = 1:CTS.Q-1
            if (target_bay - QC[q-1].next_bay) > CTS.delta && (target_bay - QC[q-1].current_bay) > CTS.delta
                if length(QC[q-1].task_buffer) > 0
                    for t_buffer in QC[q-1].task_buffer
                        if (target_bay - t_buffer.b) <= CTS.delta
                            return(false)
                        end
                    end
                end
                m+=1
            end
        end
        if m==CTS.Q-1
            return(true)
        end
    else
        if target_bay < QC[q].current_bay
            for n = 1:q-1
                if (target_bay - QC[q-1].next_bay)> CTS.delta && (target_bay - QC[q-1].current_bay) > CTS.delta
                    if length(QC[q-1].task_buffer) > 0
                        for t_buffer in QC[q-1].task_buffer
                            if (target_bay - t_buffer.b) <= CTS.delta
                                return(false)
                            end
                        end
                    end
                    m+=1
                end
            end
            if m==CTS.Q-1
                return(true)
            end
        elseif target_bay > QC[q].current_bay
            for n = q+1:CTS.Q
                if (QC[q+1].next_bay - target_bay) > CTS.delta && (QC[q+1].current_bay - target_bay) > CTS.delta
                    if length(QC[q+1].task_buffer) > 0
                        for t_buffer in QC[q+1].task_buffer
                            if (t_buffer.b - target_bay) <= CTS.delta
                                return(false)
                            end
                        end
                    end
                    m+=1
                end
            end
            if m==CTS.Q-1
                return(true)
            end
        end
    end
    return(false)
end

function check_double_clearance(QC::Array{QuayCrane, 1}, q::Int, target_bay::Int, CTS::Constants)
    if CTS.Q > 2
        if q <= 2 && target_bay > QC[q].current_bay
            if QC[q+1].status == "idle" && (QC[q+2].next_bay - target_bay) > CTS.delta + 2
                    return(true, q+1, target_bay + CTS.delta + 1, "idle")
            elseif QC[q+1].status == "moving" && (QC[q+1].next_bay - target_bay) > CTS.delta
                    return(true, q+1, target_bay + CTS.delta + 1, "moving")
            end
        elseif q >= CTS.Q - 1 && target_bay < QC[q].current_bay
            if QC[q-1].status == "idle" && (target_bay - QC[q-2].next_bay) > CTS.delta + 2
                    return(true, q-1, target_bay - CTS.delta - 1, "idle")
            elseif QC[q-1].status == "moving" && (target_bay - QC[q-1].next_bay) > CTS.delta
                    return(true, q-1, target_bay - CTS.delta - 1, "moving")
            end
        elseif 2 < q && q < CTS.Q - 1
            if target_bay < QC[q].current_bay
                if QC[q-1].status == "idle" && (target_bay - QC[q-2].current_bay) > CTS.delta + 2 && (target_bay - QC[q-2].next_bay) > CTS.delta + 2
                        return(true, q-1, target_bay - CTS.delta - 1, "idle")
                elseif QC[q-1].status == "moving" && (target_bay - QC[q-1].next_bay) > CTS.delta
                        return(true, q-1, target_bay - CTS.delta - 1, "moving")
                end
            elseif target_bay > QC[q].current_bay
                if QC[q+1].status == "idle" && (QC[q+2].next_bay - target_bay) > CTS.delta + 2
                        return(true, q+1, target_bay + CTS.delta + 1, "idle")
                elseif QC[q+1].status == "moving" && (QC[q+1].next_bay - target_bay) > CTS.delta
                        return(true, q+1, target_bay + CTS.delta + 1, "moving")
                end
            end
        end
    else
        if q == 1 && target_bay > QC[q].current_bay
            #if crane is idle, look if there is enough space to move it
            if QC[q+1].status == "idle" && target_bay < CTS.J - CTS.delta
                return(true, q+1, target_bay + CTS.delta + 1, "idle")
            #if crane is moving, look if it will move enough
            elseif QC[q+1].status == "moving" && (QC[q+1].next_bay - target_bay) > CTS.delta
                if target_bay < CTS.J - CTS.delta
                    return(true, q+1, target_bay + CTS.delta + 1, "moving")
                end
            end
        elseif q == CTS.Q && target_bay < QC[q].current_bay
            #if crane is idle, look if there is enough space to move it
            if QC[q-1].status == "idle" && target_bay > CTS.delta + 1
                return(true, q-1, target_bay - CTS.delta - 1, "idle")
            #if crane is moving, look if it will move enough
            elseif QC[q-1].status == "moving" && (target_bay - QC[q-1].next_bay) > CTS.delta
                if target_bay > 1 + CTS.delta
                    return(true, q-1, target_bay - CTS.delta - 1, "moving")
                end
            end
        end
    end
    return(false, 0, 0, "false")
end

function check_triple_clearance(QC::Array{QuayCrane, 1}, q::Int, target_bay::Int, CTS::Constants)
    if CTS.Q > 2
        if q == 1 && target_bay > QC[q].current_bay
            if QC[q+1].status == "idle" && QC[q+2].status == "idle" && (QC[q+3].next_bay - target_bay) > CTS.delta + 4
                    return(true, q+1, target_bay + CTS.delta + 1, q+2, target_bay + CTS.delta + 3)
            end
        elseif q == CTS.Q && target_bay < QC[q].current_bay
            if QC[q-1].status == "idle" && QC[q-2].status == "idle" && (target_bay - QC[q-3].next_bay) > CTS.delta + 4
                    return(true, q-1, target_bay - CTS.delta - 1, q-2, target_bay - CTS.delta - 3)
            end
        elseif q == 2 && target_bay > QC[q].current_bay
            if QC[q+1].status == "idle" && QC[q+2].status == "idle" && (CTS.J - target_bay) > CTS.delta + 4
                    return(true, q+1, target_bay + CTS.delta + 1, q+2, target_bay + CTS.delta + 3)
            end
        elseif q == 3 && target_bay < QC[q].current_bay
            if QC[q-1].status == "idle" && QC[q-2].status == "idle" && (target_bay - 1) > CTS.delta + 4
                    return(true, q-1, target_bay - CTS.delta - 1, q-2, target_bay - CTS.delta - 3)
            end
        end
    end
    return(false, 0, 0, 0, 0)
end

function is_crane_done(q::Int, QC::Array{QuayCrane,1}, CTS::Constants)
    work_load = 0
    for j in QC[q].available_bays
        work_load += remaining_bay_time(j, tasks_by_w, bj, LS, CTS)
    end
    if work_load == 0
        return(true)
    else
        return(false)
    end
end











#check if a solution is correct
function check_solution(prec::Dict{Int, Array}, LS::LoadingSequence, CTS::Constants)
    #check positions and containers
    if check_tasks(LS, CTS) == false
        # println("missing tasks")
        return(false)
    end

    #check precedences are followed
    for task in LS.order
        if task[1].p != 0
            if check_prec(LS, task[1], prec) == false
                println("wrong precedences")
                return(false)
            end
        end
    end

    #check the QC constraints
    QC_MOVES=get_qc_moves(LS, CTS)
    QC_TRAVEL=get_qc_travel(QC_MOVES, CTS)
    for clock = 1:total_makespan(LS, CTS)
        # println()
        # println("|||||||||||   "*string(clock)*"   ||||||||||||||")
        # println()
        current_cranes=Array{Tuple{Int, Number}, 1}()
        # println("LOADING CRANE")
        for (key, value) in QC_MOVES
            if clock == 1
                for i = 1: length(value)-1
                    #check loading + travel time
                    if value[i].end_time + travel_time(value[i].bay, value[i+1].bay, CTS) > value[i+1].start_time
                        # println("wrong task/travel time")
                        # println("QUAY CRANE: "*string(key))
                        # println(value[i])
                        # println(value[i+1])
                        # println("-------------- ")
                        return(false)
                    end
                    #check that cranes respect bays
                    if !(value[i].bay in subset_bay(CTS, key))
                        println("wrong bays")
                        return(false)
                    end
                end
                if !(value[length(value)].bay in subset_bay(CTS, key))
                    println("wrong bays")
                    return(false)
                end
            end

            for tuple in value
                if tuple.start_time <= clock && clock <= tuple.start_time + 2*tuple.time
                    push!(current_cranes, (key, tuple.bay))
                    # println("time: "*string(clock)*", crane: "*string(key)*", bay: "*string(tuple.bay))
                end
            end
        end

        # println("-----------------------------")
        # println("MOVING CRANE")
        for (key_travel, value_travel) in QC_TRAVEL
            for tuple in value_travel
                if tuple.start_time <= clock && clock <= tuple.end_time && tuple.start_bay != tuple.end_bay
                    current_bay = (clock-tuple.end_time)*(tuple.start_bay-tuple.end_bay)/(tuple.start_time-tuple.end_time) + tuple.end_bay
                    push!(current_cranes, (key_travel, current_bay))
                    # println("time: "*string(clock)*", crane: "*string(key_travel)*", bay: "*string(current_bay))
                end
            end
        end
        # println("-----------------------------")

        #check clearance
        sort(current_cranes, by = first)
        unique!(current_cranes)
        #println(current_cranes)

        for b = 1:length(current_cranes)-1
            if abs(current_cranes[b][2] - current_cranes[b+1][2]) <= CTS.delta
                # println(QC)
                # println("wrong clearance")
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
function plot_solution(LS::LoadingSequence, makespan::Int, CTS::Constants)
    QC_MOVES=get_qc_moves(LS, CTS)
    QC_TRAVEL=get_qc_travel(QC_MOVES, CTS)

    list_moves=[]
    list_travel=[]
    for n=1:CTS.Q
        push!(list_moves, DataFrame(Bay = [x.bay for x in QC_MOVES[n]], Start = [x.start_time for x in QC_MOVES[n]], End = [x.end_time for x in QC_MOVES[n]], QuayCrane = map(i -> "QC - " * string(i), n)))
        push!(list_travel, DataFrame(start_bay = [x.start_bay for x in QC_TRAVEL[n]], end_bay = [x.end_bay for x in QC_TRAVEL[n]], start_time = [x.start_time for x in QC_TRAVEL[n]], end_time = [x.end_time for x in QC_TRAVEL[n]], QuayCrane = map(i -> "QC - " * string(i), n)))
    end
    df_moves=vcat(list_moves...)
    df_travel=vcat(list_travel...)

    #plot scale
    xsc  = Scale.x_continuous(minvalue=0, maxvalue=makespan)
    ysc  = Scale.y_continuous(minvalue=0, maxvalue=CTS.J+1)
    xtk = collect(0:60:makespan)
    push!(xtk, makespan)
    ytk = collect(1:CTS.J)
    #plot(df, x = :Start, xend = :Time, y = :Bay, yend = :Bay, color = :QuayCrane, Geom.segment(filled=false), Theme(line_width=1cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
          #     major_label_font_size=16pt,minor_label_font_size=14pt), xsc, ysc)

    layer1 = layer(df_moves, x = :Start, xend = :End, y = :Bay, yend = :Bay, color = :QuayCrane, Geom.segment(filled=false), Theme(alphas=[0.5], line_width=0.25cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
               major_label_font_size=16pt,minor_label_font_size=14pt))
    layer2 = layer(df_travel, x = :start_time, xend = :end_time, y = :start_bay, yend = :end_bay, color = :QuayCrane, Geom.segment(filled=false), Theme(line_style=[:dot] ,line_width=0.05cm, major_label_font="CMU Serif",minor_label_font="CMU Serif",
               major_label_font_size=16pt,minor_label_font_size=14pt))

    plot(layer1, layer2, xsc, ysc, Guide.xticks(ticks=xtk), Guide.yticks(ticks=ytk))

end
