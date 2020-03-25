function next_time_period(TIME::Timer, QC::Array{QuayCrane, 1})
    TIME.period += 1
    l = Array{Int, 1}()
    #update all QC atr
    for qc in QC

        if qc.status == "moving"
            if qc.current_bay > qc.next_bay
                qc.current_bay -= 1
            else qc.current_bay < qc.next_bay
                qc.current_bay += 1
            end
        end

        if qc.time_left > 1
            qc.time_left -= 1
        elseif qc.time_left == 1
            if length(task_buffer) == 1
                QC[q].time_left = QC[q].task_buffer.t
                QC[q].status = "loading"
                QC[q].task_buffer = []
            else
                qc.time_left = 0
                qc.status = "idle"
                push!(l, qc.q)
        end
    end
    TIME.available_cranes = l
end

function travel_time(current_bay::Int, target_bay::Int, CTS::Constants)
    return(abs(current_bay - target_bay)*CTS.tt)
end

function update_quay_crane(TIME::Timer, QC::Array{QuayCrane, 1}, task::Task  q::Int, CTS::Constants)
    if task.b == QC[q].current_bay
        QC[q].time_left = task.t
        QC[q].status = "loading"
    else
        QC[q].time_left = travel_time(QC[q].current_bay, task.b, CTS)
        QC[q].status = "moving"
        QC[q].task_buffer = [task]
    end
end

function update_load_seq(TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, task::Task, precedences::Dict, q::Int, CTS::Constants)
    LS.len += 1
    LS.tasks_left -= 1
    start_time = travel_time(QC[q].current_bay, task.b, CTS) + TIME.period
    push!(LS.order, (task=task, start_time=start_time, quay_crane=q)
    push!(LS.filled_pos, task.p)
    push!(LS.loaded_cont,task.c)
end

function add_task(TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, task::Task, precedences::Dict, q::Int, CTS::Constants)
    if !(task.c in LS.loaded) && !(task.p in LS.filled)
        if check_precedences(LS, task, precedences) == true
            if task.p in QC[q].available_bays && QC[q].status == "idle"
                    if check_clearance(QC, q, task.b, CTS) == true
                        update_load_seq(TIME, LS, QC, task, precedences, q, CTS)
                        update_quay_crane(TIME, QC, task,  q, CTS)
                        return(true)
                    else
                        return("clearance")
            else
                return("crane not available")
        else
            return("precedences")
        end
    else
        return("already loaded/filed")
    end
end
