function next_time_period(TIME::Timer, QC::Array{QuayCrane, 1})
    TIME.period += 1
    l = Array{Int, 1}()
    #update all QC atributtes
    for qc in QC
        #update QC position
        if qc.status == "moving"
            if  qc.next_bay < qc.current_bay
                qc.current_bay -= CTS.tt
            elseif qc.current_bay < qc.next_bay
                qc.current_bay += CTS.tt
            end
        end
        #update QC time left and status
        if qc.time_left > 1
            qc.time_left -= 1
        elseif qc.time_left == 1
            if length(qc.task_buffer) > 0 && qc.status != "waiting to move"
                qc.time_left = 2*qc.task_buffer[1].t
                qc.status = "loading"
                deleteat!(qc.task_buffer, 1)
            elseif length(qc.task_buffer) > 0 && qc.status == "waiting to move"
                qc.time_left = travel_time(qc.current_bay, qc.task_buffer[1].b, CTS)
                qc.status = "moving"
            else
                qc.time_left = 0
                qc.status = "idle"
            end
        end
        if qc.status == "idle"
            push!(l, qc.q)
        end
    end
    TIME.available_cranes = l
    #println(TIME)
end

function travel_time(current_bay::Int, target_bay::Int, CTS::Constants)
    return(abs(current_bay - target_bay)*CTS.tt)
end

function update_quay_crane(TIME::Timer, QC::Array{QuayCrane, 1}, task::Task, q::Int, CTS::Constants)
    if task.b == QC[q].current_bay
        QC[q].time_left = 2*task.t
        QC[q].status = "loading"
        QC[q].next_bay = QC[q].current_bay
    else
        QC[q].time_left = travel_time(QC[q].current_bay, task.b, CTS)
        QC[q].status = "moving"
        QC[q].next_bay = task.b
        if task.t != 0 && task.p !=0
            push!(QC[q].task_buffer, task)
        end
    end
end

function update_load_seq(TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, task::Task, q::Int, CTS::Constants)
    LS.len += 1
    LS.tasks_left -= 1
    start_time = TIME.period + travel_time(QC[q].current_bay, task.b, CTS)
    push!(LS.order, (task=task, start_time=start_time, qc=q))
    push!(LS.filled_pos, task.p)
    push!(LS.loaded_cont,task.c)
end

function update_wait_quay_crane(TIME::Timer, QC::Array{QuayCrane, 1}, task::Task, q::Int, move_q::Int, move_bay::Int, CTS::Constants)
    if task.b == QC[q].current_bay
        QC[q].time_left = travel_time(QC[move_q].current_bay, QC[move_q].next_bay, CTS)
        QC[q].status = "waiting to start"
        QC[q].next_bay = QC[q].current_bay
        push!(QC[q].task_buffer, task)
    elseif travel_time(QC[q].current_bay, task.b, CTS) >= travel_time(QC[move_q].current_bay, QC[move_q].next_bay, CTS)
        QC[q].time_left = travel_time(QC[q].current_bay, task.b, CTS)
        QC[q].status = "moving"
        QC[q].next_bay = task.b
        if task.t != 0 && task.p !=0
            push!(QC[q].task_buffer, task)
        end
    else
        QC[q].time_left = travel_time(QC[move_q].current_bay, QC[move_q].next_bay, CTS) - travel_time(QC[q].current_bay, task.b, CTS)
        QC[q].status = "waiting to move"
        QC[q].next_bay = task.b
        if task.t != 0 && task.p !=0
            push!(QC[q].task_buffer, task)
        end
    end
end

function update_wait_load_seq(TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, task::Task, q::Int, move_q::Int, move_bay::Int, CTS::Constants)
    LS.len += 1
    LS.tasks_left -= 1
    start_time = TIME.period + max(travel_time(QC[q].current_bay, task.b, CTS), travel_time(QC[move_q].current_bay, QC[move_q].next_bay, CTS))
    push!(LS.order, (task=task, start_time=start_time, qc=q))
    push!(LS.filled_pos, task.p)
    push!(LS.loaded_cont,task.c)
end

function add_task(task::Task, q::Int, TIME::Timer, LS::LoadingSequence, QC::Array{QuayCrane, 1}, CTS::Constants)
    update_load_seq(TIME, LS, QC, task, q, CTS)
    update_quay_crane(TIME, QC, task, q, CTS)
    deleteat!(TIME.available_cranes, findall(x->x==q, TIME.available_cranes))
end

function add_task_move(task::Task, q::Int, move_q::Int, move_bay::Int, move_status::String, LS::LoadingSequence, TIME::Timer, QC::Array{QuayCrane, 1}, CTS::Constants)
    if move_status == "idle"
        update_quay_crane(TIME, QC, Task(0, move_bay, 0, 0), move_q, CTS)
        update_wait_quay_crane(TIME, QC, task, q, move_q, move_bay, CTS)
        update_wait_load_seq(TIME, LS, QC, task, q, move_q, move_bay, CTS)
        deleteat!(TIME.available_cranes, findall(x->x==q, TIME.available_cranes))
        deleteat!(TIME.available_cranes, findall(x->x==move_q, TIME.available_cranes))
    elseif move_status == "moving"
        update_wait_quay_crane(TIME, QC, task, q, move_q, move_bay, CTS)
        update_wait_load_seq(TIME, LS, QC, task, q, move_q, move_bay, CTS)
        deleteat!(TIME.available_cranes, findall(x->x==q, TIME.available_cranes))
        deleteat!(TIME.available_cranes, findall(x->x==move_q, TIME.available_cranes))
    end
end
