function remove_tasks(gamma::Float64, LS::LoadingSequence, CTS::Constants)
    new_LS = init_ls(CTS::Constants)
    for t = 1:Int(floor(CTS.P*gamma))
        new_LS.len += 1
        new_LS.tasks_left -= 1
        push!(new_LS.order, LS.order[t])
        push!(new_LS.filled_pos, LS.order[t].task.p)
        push!(new_LS.loaded_cont, LS.order[t].task.c)
    end
    return(new_LS)
end


function last_qc_moves(LS::LoadingSequence, CTS::Constants)
    QC_MOVES=Dict{Int, Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}}()
    min_q = (q=0, end_time=CTS.H, start_time=CTS.H, time=CTS.H)

    flag = Array{Int,1}()
    while Set(collect(1:CTS.Q)) != Set(flag)
        for t in reverse(LS.order)
            for q = 1:CTS.Q
                if t.qc == q && !(q in flag)
                    push!(flag, q)
                    if t.start_time + 2*t.task.t < min_q.end_time
                        min_q = (q=q, end_time=t.start_time + 2*t.task.t, start_time=t.start_time, time = t.task.t)
                        break
                    end
                end
            end
        end
    end

    flag = Array{Int,1}()
    while Set(collect(1:CTS.Q)) != Set(flag)
        for q = 1:CTS.Q
            l=Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}()
            for t in reverse(LS.order)
                if t.qc == q
                    if t.start_time > min_q.end_time
                        push!(l, (bay=t.task.b, end_time=t.start_time + 2*t.task.t, start_time=t.start_time, time=t.task.t))
                    else
                        push!(l, (bay=t.task.b, end_time=t.start_time + 2*t.task.t, start_time=t.start_time, time=t.task.t))
                        push!(flag, q)
                        break
                    end
                end
            end
            QC_MOVES[q]=reverse(l)
        end
    end
    return(min_q, QC_MOVES)
end


function get_current_state(LS::LoadingSequence, CTS::Constants)
    TIME = init_timer(CTS)
    TIME.available_cranes = Array{Int, 1}()
    QC = init_qc(CTS)
    min_q, QC_MOVES = last_qc_moves(LS, CTS)
    QC_TRAVEL = get_qc_travel(QC_MOVES, CTS)

    TIME.period = min_q.end_time
    TIME.available_cranes = Array{Int, 1}()

    for q = 1:CTS.Q
        QC[q].task_buffer = Array{Task, 1}()
        #idle crane
        if QC_MOVES[q][end].end_time == TIME.period
            QC[q].status = "idle"
            QC[q].time_left = 0
            QC[q].current_bay = QC_MOVES[q][end].bay
            QC[q].next_bay = QC_MOVES[q][end].bay
            push!(TIME.available_cranes, q)
        #loading crane
        elseif TIME.period >= QC_MOVES[q][end].start_time
            QC[q].status = "loading"
            QC[q].time_left = QC_MOVES[q][end].end_time - TIME.period
            QC[q].current_bay = QC_MOVES[q][end].bay
            QC[q].next_bay = QC_MOVES[q][end].bay
        #moving or waiting to move/load crane
    elseif QC_MOVES[q][end-1].end_time <= TIME.period && TIME.period < QC_MOVES[q][end].start_time
            QC[q].next_bay = QC_MOVES[q][end].bay
            push!(QC[q].task_buffer, Task(0, QC_MOVES[q][end].bay, 0, QC_MOVES[q][end].time))
            if QC_MOVES[q][end-1].bay == QC_MOVES[q][end].bay
                QC[q].status = "waiting to load"
                QC[q].time_left = QC_MOVES[q][end].start_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end].bay
            elseif QC_TRAVEL[q][1].start_time <= TIME.period
                QC[q].status = "moving"
                QC[q].time_left = QC_TRAVEL[q][1].end_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end].bay - QC[q].time_left*CTS.tt
            else
                QC[q].status = "waiting to move"
                QC[q].time_left = QC_TRAVEL[q][1].start_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end-1].bay
            end
        #still loading the previous task
        else
            QC[q].status = "loading"
            QC[q].time_left = QC_MOVES[q][end-1].end_time - TIME.period
            QC[q].current_bay = QC_MOVES[q][end-1].bay
            QC[q].next_bay = QC_MOVES[q][end].bay
            push!(QC[q].task_buffer, Task(0, QC_MOVES[q][end].bay, 0, QC_MOVES[q][end].time))
        end
    end
    return(TIME, QC)
end


function reschedule_tasks(LS::LoadingSequence, CTS::Constants)
    new_LS = remove_tasks(gamma, LS, CTS)
    TIME, QC = get_current_state(new_LS, CTS)
    #perform GRASP with other indicators

end
