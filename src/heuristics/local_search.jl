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
        QC[q].task_buffer = Array{LTask, 1}()
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
            push!(QC[q].task_buffer, LTask(0, QC_MOVES[q][end].bay, 0, QC_MOVES[q][end].time))
            if QC_MOVES[q][end-1].bay == QC_MOVES[q][end].bay
                QC[q].status = "waiting to load"
                QC[q].time_left = QC_MOVES[q][end].start_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end].bay
            elseif QC_TRAVEL[q][1].start_time <= TIME.period
                QC[q].status = "moving"
                QC[q].time_left = QC_TRAVEL[q][1].end_time - TIME.period
                QC[q].current_bay = QC_MOVES[q][end].bay - QC[q].time_left/CTS.tt
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
                push!(QC[q].task_buffer, LTask(0, QC_MOVES[q][end].bay, 0, QC_MOVES[q][end].time))
            end
        else
            for i = 1:length(QC_MOVES[q])-1
                #moving or waiting to move/load crane
                if QC_MOVES[q][i].end_time <= TIME.period && TIME.period < QC_MOVES[q][i+1].start_time
                    QC[q].next_bay = QC_MOVES[q][i+1].bay
                    for i = 1:length(QC_MOVES[q])-1
                        push!(QC[q].task_buffer, LTask(0, QC_MOVES[q][i+1].bay, 0, QC_MOVES[q][i+1].time))
                    end
                    if QC_MOVES[q][i].bay == QC_MOVES[q][i+1].bay
                        QC[q].status = "waiting to load"
                        QC[q].time_left = QC_MOVES[q][i+1].start_time - TIME.period
                        QC[q].current_bay = QC_MOVES[q][i+1].bay
                    elseif QC_TRAVEL[q][1].start_time <= TIME.period
                        QC[q].status = "moving"
                        QC[q].time_left = QC_TRAVEL[q][1].end_time - TIME.period
                        QC[q].current_bay = QC_MOVES[q][i+1].bay - QC[q].time_left/CTS.tt
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
                        push!(QC[q].task_buffer, LTask(0, QC_MOVES[q][i+1].bay, 0, QC_MOVES[q][i+1].time))
                    end
                end
            end
        end
    end
    return(true, TIME, QC)
end











function get_single_moves(QC_MOVES::Dict{Int, Array{NamedTuple{(:bay, :end_time, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, 1}}, CTS::Constants)
    single_moves = Array{NamedTuple{(:qc, :bay, :start_time, :time),Tuple{Int64, Int64, Int64, Int64}},1}()
    check = false
    for q = 1:CTS.Q
        for t = 2:length(QC_MOVES[q])-1
            if QC_MOVES[q][t-1].bay < QC_MOVES[q][t].bay && QC_MOVES[q][t].bay > QC_MOVES[q][t+1].bay
                if QC_MOVES[q][t].time != 0
                    push!(single_moves, (qc=q, bay=QC_MOVES[q][t].bay, start_time = QC_MOVES[q][t].start_time, time = QC_MOVES[q][t].time))
                    check = true
                end
            elseif QC_MOVES[q][t-1].bay > QC_MOVES[q][t].bay && QC_MOVES[q][t].bay < QC_MOVES[q][t+1].bay
                if QC_MOVES[q][t].time != 0
                    push!(single_moves, (qc=q, bay=QC_MOVES[q][t].bay, start_time = QC_MOVES[q][t].start_time, time = QC_MOVES[q][t].time))
                    check = true
                end
            end
        end

        if QC_MOVES[q][end-1].bay != QC_MOVES[q][end-2].bay && QC_MOVES[q][end-1].time != 0
            push!(single_moves, (qc=q, bay=QC_MOVES[q][end-1].bay, start_time = QC_MOVES[q][end-1].start_time, time = QC_MOVES[q][end-1].time))
            check = true
        end
        if QC_MOVES[q][1].bay != init_bay(q,CTS) && QC_MOVES[q][1].bay != QC_MOVES[q][2].bay && QC_MOVES[q][2].time != 0
            push!(single_moves, (qc=q, bay=QC_MOVES[q][1].bay, start_time = QC_MOVES[q][1].start_time, time = QC_MOVES[q][1].time))
            check = true
        end
    end

    if check == false
        return(false)
    else
        return(single_moves)
    end
end

function get_single_task(single::NamedTuple{(:qc, :bay, :start_time, :time),Tuple{Int64,Int64,Int64,Int64}}, LS::LoadingSequence, CTS::Constants)
    single_task = (task=LTask(0,0,0,0), start_time=0, qc=0)
    left_flag = false
    right_flag = false
    l = Array{NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}},1}()
    r = Array{NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}},1}()
    for t in LS.order
        #single taks
        if t.start_time == single.start_time && t.qc == single.qc && t.task.b == single.bay && t.task.t == single.time
                single_task = t
        end
        if t.start_time < single.start_time && t.task.b == single.bay && t.qc == single.qc
            if left_flag == false
                left_flag = true
            elseif l[end].start_time + 2*l[end].task.t == t.start_time
                deleteat!(l, length(l))
            end
            push!(l, t)
        elseif single.start_time < t.start_time && t.task.b == single.bay && t.qc == single.qc
            if right_flag == false
                right_flag = true
            elseif r[end].start_time + 2*r[end].task.t == t.start_time
                deleteat!(r, length(r))
            end
            push!(r, t)
        end
    end

    return(single_task, left_flag, right_flag, l, r)
end

function trim_left(single::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, left::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, LS::LoadingSequence, CTS::Constants)
    LS1 = deepcopy(LS)
    LS2 = deepcopy(LS)
    LS3 = deepcopy(LS)

    #delete single_task
    deleteat!(LS1.filled_pos, findall(x->x==single.task.p, LS1.filled_pos))
    deleteat!(LS1.loaded_cont, findall(x->x==single.task.c, LS1.loaded_cont))
    deleteat!(LS1.order, findall(x->x==single, LS1.order))
    deleteat!(LS2.filled_pos, findall(x->x==single.task.p, LS2.filled_pos))
    deleteat!(LS2.loaded_cont, findall(x->x==single.task.c, LS2.loaded_cont))
    deleteat!(LS2.order, findall(x->x==single, LS2.order))
    deleteat!(LS3.filled_pos, findall(x->x==single.task.p, LS3.filled_pos))
    deleteat!(LS3.loaded_cont, findall(x->x==single.task.c, LS3.loaded_cont))
    deleteat!(LS3.order, findall(x->x==single, LS3.order))

    #trim LS
    for t in LS.order
        if  left.start_time < t.start_time
            deleteat!(LS1.filled_pos, findall(x->x==t.task.p, LS1.filled_pos))
            deleteat!(LS1.loaded_cont, findall(x->x==t.task.c, LS1.loaded_cont))
            deleteat!(LS1.order, findall(x->x==t, LS1.order))
            if single.start_time <= t.start_time
                deleteat!(LS2.filled_pos, findall(x->x==t.task.p, LS2.filled_pos))
                deleteat!(LS2.loaded_cont, findall(x->x==t.task.c, LS2.loaded_cont))
                deleteat!(LS2.order, findall(x->x==t, LS2.order))
            elseif t.start_time <= single.start_time + 2*single.task.t
                deleteat!(LS3.filled_pos, findall(x->x==t.task.p, LS3.filled_pos))
                deleteat!(LS3.loaded_cont, findall(x->x==t.task.c, LS3.loaded_cont))
                deleteat!(LS3.order, findall(x->x==t, LS3.order))
            end
        elseif t.start_time <= left.start_time
            deleteat!(LS2.filled_pos, findall(x->x==t.task.p, LS2.filled_pos))
            deleteat!(LS2.loaded_cont, findall(x->x==t.task.c, LS2.loaded_cont))
            deleteat!(LS2.order, findall(x->x==t, LS2.order))
            deleteat!(LS3.filled_pos, findall(x->x==t.task.p, LS3.filled_pos))
            deleteat!(LS3.loaded_cont, findall(x->x==t.task.c, LS3.loaded_cont))
            deleteat!(LS3.order, findall(x->x==t, LS3.order))
        end
    end

    return(LS1, LS2, LS3)
end

function trim_right(single::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, right::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, LS::LoadingSequence, CTS::Constants)
    LS1 = deepcopy(LS)
    LS2 = deepcopy(LS)
    LS3 = deepcopy(LS)

    #delete single_task
    deleteat!(LS1.filled_pos, findall(x->x==single.task.p, LS1.filled_pos))
    deleteat!(LS1.loaded_cont, findall(x->x==single.task.c, LS1.loaded_cont))
    deleteat!(LS1.order, findall(x->x==single, LS1.order))
    deleteat!(LS2.filled_pos, findall(x->x==single.task.p, LS2.filled_pos))
    deleteat!(LS2.loaded_cont, findall(x->x==single.task.c, LS2.loaded_cont))
    deleteat!(LS2.order, findall(x->x==single, LS2.order))
    deleteat!(LS3.filled_pos, findall(x->x==single.task.p, LS3.filled_pos))
    deleteat!(LS3.loaded_cont, findall(x->x==single.task.c, LS3.loaded_cont))
    deleteat!(LS3.order, findall(x->x==single, LS3.order))

    #trim LS
    for t in LS.order
        if  t.start_time >= single.start_time
            deleteat!(LS1.filled_pos, findall(x->x==t.task.p, LS1.filled_pos))
            deleteat!(LS1.loaded_cont, findall(x->x==t.task.c, LS1.loaded_cont))
            deleteat!(LS1.order, findall(x->x==t, LS1.order))
            if t.start_time >= right.start_time + 2*right.task.t
                deleteat!(LS2.filled_pos, findall(x->x==t.task.p, LS2.filled_pos))
                deleteat!(LS2.loaded_cont, findall(x->x==t.task.c, LS2.loaded_cont))
                deleteat!(LS2.order, findall(x->x==t, LS2.order))
            elseif t.start_time <= right.start_time
                deleteat!(LS3.filled_pos, findall(x->x==t.task.p, LS3.filled_pos))
                deleteat!(LS3.loaded_cont, findall(x->x==t.task.c, LS3.loaded_cont))
                deleteat!(LS3.order, findall(x->x==t, LS3.order))
            end
        elseif t.start_time < single.start_time
            deleteat!(LS2.filled_pos, findall(x->x==t.task.p, LS2.filled_pos))
            deleteat!(LS2.loaded_cont, findall(x->x==t.task.c, LS2.loaded_cont))
            deleteat!(LS2.order, findall(x->x==t, LS2.order))
            deleteat!(LS3.filled_pos, findall(x->x==t.task.p, LS3.filled_pos))
            deleteat!(LS3.loaded_cont, findall(x->x==t.task.c, LS3.loaded_cont))
            deleteat!(LS3.order, findall(x->x==t, LS3.order))
        end
    end
    return(LS1, LS2, LS3)
end

function merge_left(single::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, LS1::LoadingSequence, LS2::LoadingSequence, LS3::LoadingSequence, CTS::Constants)
    #merge single task
    push!(LS1.order, (task=single.task, start_time = get_qc_last_time(single.qc, LS1) + travel_time(get_qc_last_bay(single.qc, LS1), single.task.b, CTS), qc=single.qc))
    push!(LS1.filled_pos, single.task.p)
    push!(LS1.loaded_cont, single.task.c)
    #update and merge LS2
    for t in LS2.order
        if t.qc == single.qc
            nt = (task=t.task, start_time = t.start_time + 2*single.task.t, qc=single.qc)
            push!(LS1.order, nt)
        else
            push!(LS1.order, t)
        end
        push!(LS1.filled_pos, t.task.p)
        push!(LS1.loaded_cont, t.task.c)
    end
    #update and merge LS3
    if length(LS3.order) > 0
    dif = 2*travel_time(get_qc_last_bay(single.qc, LS2), single.task.b, CTS)
        for t in LS3.order
            if t.qc == single.qc
                nt = (task=t.task, start_time = t.start_time - dif, qc=single.qc)
                push!(LS1.order, nt)
            else
                push!(LS1.order, t)
            end
            push!(LS1.filled_pos, t.task.p)
            push!(LS1.loaded_cont, t.task.c)
        end
    end
    return(LS1)
end

function merge_right(single::NamedTuple{(:task, :start_time, :qc),Tuple{LTask,Int64,Int64}}, LS1::LoadingSequence, LS2::LoadingSequence, LS3::LoadingSequence, CTS::Constants)
    #update and merge LS2
    if length(LS1.order) > 0
        dif = 2*travel_time(get_qc_last_bay(single.qc, LS1), single.task.b, CTS) + 2*single.task.t
    else
        dif = 2*travel_time(init_bay(single.qc, CTS), single.task.b, CTS) + 2*single.task.t
    end
    for t in LS2.order
        if t.qc == single.qc
            nt = (task=t.task, start_time = t.start_time - dif, qc=single.qc)
            push!(LS1.order, nt)
        else
            push!(LS1.order, t)
        end
        push!(LS1.filled_pos, t.task.p)
        push!(LS1.loaded_cont, t.task.c)
    end

    #merge single task
    push!(LS1.order, (task=single.task, start_time = get_qc_last_time(single.qc, LS1) + travel_time(get_qc_last_bay(single.qc, LS1), single.task.b, CTS), qc=single.qc))
    push!(LS1.filled_pos, single.task.p)
    push!(LS1.loaded_cont, single.task.c)

    #update and merge LS3
    dif = dif - 2*single.task.t
    for t in LS3.order
        if t.qc == single.qc
            nt = (task=t.task, start_time = t.start_time - dif, qc=single.qc)
            push!(LS1.order, nt)
        else
            push!(LS1.order, t)
        end
        push!(LS1.filled_pos, t.task.p)
        push!(LS1.loaded_cont, t.task.c)
    end
    return(LS1)
end

function remove_single_moves(prec::Dict{Int, Array}, makespan::Int, LS::LoadingSequence, CTS::Constants)
    QC_MOVES = get_qc_moves(LS, CTS)
    single_moves = get_single_moves(QC_MOVES, CTS)
    if single_moves == false
        return(LS)
    else
        for single in single_moves
            if single.qc == LS.order[end].qc
                single_task, left_flag, right_flag, l, r = get_single_task(single, LS, CTS)
                if left_flag == true
                    for l_task in l
                        LS1, LS2, LS3 = trim_left(single_task, l_task, LS, CTS)
                        new_LS = merge_left(single_task, LS1, LS2, LS3, CTS)
                        if check_solution(prec, new_LS, CTS) == true
                            if total_makespan(new_LS, CTS) < makespan
                                return(new_LS)
                            end
                        end
                    end
                end
                if right_flag == true
                    for r_task in r
                        LS1, LS2, LS3 = trim_right(single_task, r_task, LS, CTS)
                        new_LS = merge_right(single_task, LS1, LS2, LS3, CTS)
                        if check_solution(prec, new_LS, CTS) == true
                            if total_makespan(new_LS, CTS) < makespan
                                return(new_LS)
                            end
                        end
                    end
                end
            end
        end
        return(LS)
    end
end


function remove_useless_travel(LS::LoadingSequence)
    if LS.order[end].task.t == 0
        deleteat!(LS.order, length(LS.order))
    end
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
        QC[q].task_buffer = Array{LTask, 1}()
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
