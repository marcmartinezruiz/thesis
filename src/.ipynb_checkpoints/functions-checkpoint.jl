function check_prec(LS::LoadingSequence, task::Task, precedences::Dict)
    for req in precedences[task.p]
        if !(req in LS.filled)
            print("trying to add position, but still missing")
            print(setdiff(precedences[task.p],LS.filled))
            return(false)
        end
    end
    return(true)
end

function add_task(LS::LoadingSequence, task::Task, precedences::Dict, qc::Array{1, QuayCrane})
    if !(task.c in LS.loaded) && !(task.p in LS.filled)
        if check_precedences == true
            LS.len = LS.len + 1
            LS.tasks_left = LS.P - LS.len
            push!(LS.order, task)
            push!(LS.filled, task.p)
            push!(LS.loaded,task.c)
        else
            return(false)
        end
    else
        return("already done")
    end
end

function subset_pos(set, dict_by_position, pos)
    sub_set=[]
    for task in dict_by_position[pos]
        push!(sub_set, task.c)
    end
    return(sub_set)
end

function subset_bay(J, Q, delta, q)
    sub_set=[(q-1)*(delta+1)+1:J-(Q-q)*(delta+1)]
    return(sub_set)
end
