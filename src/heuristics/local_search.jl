function remove_tasks(gamma::Float64, LS::LoadingSequence, CTS::Constants)
    new_LS = deepcopy(LS)
    mod_gamma = Int(floor(CTS.P*gamma))
    if new_LS.order[mod_gamma+1].task.p == 0 && new_LS.order[mod_gamma+1].task.c == 0
        mod_gamma -= 1
    end
    for t = 1:mod_gamma
        if new_LS.order[end].task.p != 0 && new_LS.order[end].task.c != 0
            new_LS.len -= 1
            new_LS.tasks_left += 1
        end
        deleteat!(new_LS.filled_pos, findall(x->x==new_LS.order[length(new_LS.order)].task.p, new_LS.filled_pos))
        deleteat!(new_LS.loaded_cont, findall(x->x==new_LS.order[length(new_LS.order)].task.c, new_LS.loaded_cont))
        deleteat!(new_LS.order, length(new_LS.order))
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
        if QC_MOVES[q][end].end_time == TIME.period && length(QC_MOVES[q]) == 1
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
        elseif  QC_MOVES[q][end-1].start_time <= TIME.period
            if length(QC_MOVES[q]) == 2
                QC[q].status = "loading"
                QC[q].time_left = QC_MOVES[q][end-1].end_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end-1].bay
                QC[q].next_bay = QC_MOVES[q][end].bay
                push!(QC[q].task_buffer, Task(0, QC_MOVES[q][end].bay, 0, QC_MOVES[q][end].time))
            end
        else
            for i = 1:length(QC_MOVES[q])-1
                #moving or waiting to move/load crane
                if QC_MOVES[q][i].end_time <= TIME.period && TIME.period < QC_MOVES[q][i+1].start_time
                    QC[q].next_bay = QC_MOVES[q][i+1].bay
                    for i = 1:length(QC_MOVES[q])-1
                        push!(QC[q].task_buffer, Task(0, QC_MOVES[q][i+1].bay, 0, QC_MOVES[q][i+1].time))
                    end
                    if QC_MOVES[q][i].bay == QC_MOVES[q][i+1].bay
                        QC[q].status = "waiting to load"
                        QC[q].time_left = QC_MOVES[q][i+1].start_time - TIME.period
                        QC[q].current_bay = QC_MOVES[q][i+1].bay
                    elseif QC_TRAVEL[q][1].start_time <= TIME.period
                        QC[q].status = "moving"
                        QC[q].time_left = QC_TRAVEL[q][1].end_time - TIME.period
                        QC[q].current_bay = QC_MOVES[q][i+1].bay - QC[q].time_left*CTS.tt
                    else
                        QC[q].status = "waiting to move"
                        QC[q].time_left = QC_TRAVEL[q][1].start_time - TIME.period
                        QC[q].current_bay = QC_MOVES[q][i].bay
                    end
                #still loading the previous task
                elseif  QC_MOVES[q][i].start_time <= TIME.period
                    QC[q].status = "loading"
                    QC[q].time_left = QC_MOVES[q][i].end_time - TIME.period
                    QC[q].current_bay = QC_MOVES[q][i].bay
                    QC[q].next_bay = QC_MOVES[q][i].bay
                    for i = 1:length(QC_MOVES[q])-1
                        push!(QC[q].task_buffer, Task(0, QC_MOVES[q][i+1].bay, 0, QC_MOVES[q][i+1].time))
                    end
                end
            end
        end
    end
    return(true, TIME, QC)
end



function remove_final_tasks(moves::Int, LS::LoadingSequence, CTS::Constants)
    new_LS = deepcopy(LS)

    if moves > 2
        while new_LS.len >= LS.len - (moves - 2)
            if new_LS.order[end].task.p != 0 && new_LS.order[end].task.c != 0
                new_LS.len -= 1
                new_LS.tasks_left += 1
            end
            deleteat!(new_LS.filled_pos, findall(x->x==new_LS.order[length(new_LS.order)].task.p, new_LS.filled_pos))
            deleteat!(new_LS.loaded_cont, findall(x->x==new_LS.order[length(new_LS.order)].task.c, new_LS.loaded_cont))
            deleteat!(new_LS.order, length(new_LS.order))
        end
        if new_LS.order[end].task.p == 0 && new_LS.order[end].task.c == 0
            deleteat!(new_LS.order, length(new_LS.order))
        end
    end
    return(new_LS)
end

function ls_qc_moves(LS::LoadingSequence, CTS::Constants)
    QC_MOVES=Dict{Int, Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}}()
    min_q = (q=0, end_time=CTS.H, start_time=CTS.H, time=CTS.H)
    moves = 0
    flag = Array{Int,1}()
    while Set(collect(1:CTS.Q)) != Set(flag)
        for t in reverse(LS.order)
            for q = 1:CTS.Q
                if t.qc == q && !(q in flag) && t.task.t != 0
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
                        if t.task.t != 0
                            moves += 1
                        end
                    elseif t.start_time < min_q.start_time && t.start_time + 2*t.task.t < min_q.start_time
                        push!(l, (bay=t.task.b, end_time=t.start_time, start_time=t.start_time, time=0))
                        push!(flag, q)
                        break
                    else
                        push!(l, (bay=t.task.b, end_time=t.start_time + 2*t.task.t, start_time=t.start_time, time=t.task.t))
                        push!(flag, q)
                        if t.task.t != 0
                            moves += 1
                        end
                        break
                    end
                end
            end
            QC_MOVES[q]=reverse(l)
        end
    end
    return(min_q, moves, QC_MOVES)
end

function get_final_state(LS::LoadingSequence, CTS::Constants)
    TIME = init_timer(CTS)
    TIME.available_cranes = Array{Int, 1}()
    QC = init_qc(CTS)
    min_q, moves, QC_MOVES = ls_qc_moves(best_LS, CTS)
    QC_TRAVEL = get_qc_travel(QC_MOVES, CTS)

    TIME.period = min_q.end_time
    TIME.available_cranes = Array{Int, 1}()

    for q = 1:CTS.Q
        QC[q].task_buffer = Array{Task, 1}()
        #idle crane
        if QC_MOVES[q][1].end_time == TIME.period
            QC[q].status = "idle"
            QC[q].time_left = 0
            QC[q].current_bay = QC_MOVES[q][1].bay
            QC[q].next_bay = QC_MOVES[q][1].bay
            push!(TIME.available_cranes, q)
        #loading crane
        elseif QC_MOVES[q][1].start_time <= TIME.period && TIME.period < QC_MOVES[q][1].end_time
            QC[q].status = "loading"
            QC[q].time_left = QC_MOVES[q][1].end_time - TIME.period
            QC[q].current_bay = QC_MOVES[q][1].bay
            QC[q].next_bay = QC_MOVES[q][1].bay
        else
            QC[q].status = "idle"
            QC[q].time_left = 0
            QC[q].current_bay = QC_MOVES[q][1].bay
            QC[q].next_bay = QC_MOVES[q][1].bay
            push!(TIME.available_cranes, q)
        end
    end
    return(min_q.q, moves, TIME, QC)
end









function total_task_time(tasks_dict::Dict{Int, Task})
    total=0
    for (key, value) in tasks_dict
        total += value.t
    end
    return(total)
end

function container_swapping(tasks_by_w::Dict{Int, Task}, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    swapped_tasks = deepcopy(tasks_by_w)
    check = false
    while check == false
        #randomly select container and position
        c = rand(1:CTS.C)
        available_pos = Array{Int,1}()
        for p = 1:CTS.P
            if task_times[c,p] != 0
                push!(available_pos, p)
            end
        end
        p = available_pos[rand(1:length(available_pos))]

        #perform the container swap
        c_swap = 0
        p_swap = 0
        current_time = 0
        for (key, value) in swapped_tasks
            if key == p
                c_swap = value.c
                current_time += value.t
            end
            if value.c == c
                p_swap = key
                current_time += value.t
            end
        end

        if task_times[p,c] + task_times[p_swap,c_swap] <= floor(1.4*current_time)
            swapped_tasks[p] = Task(p, bj[p], c, task_times[p,c])
            swapped_tasks[p_swap] = Task(p_swap, bj[p_swap], c_swap, task_times[p_swap,c_swap])
        end

        total_swapped = total_task_time(swapped_tasks)
        total_w = total_task_time(tasks_by_w)
        if 1.05 * total_w <= total_swapped && total_swapped <= 1.15 * total_w
            return(swapped_tasks)
            check = true
        elseif total_swapped > 1.2 * total_w
            swapped_tasks = deepcopy(tasks_by_w)
        end
    end
    return(swapped_tasks)
end
