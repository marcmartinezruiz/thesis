function OperationalShippingProblem(beta::Number, task_times::Array{Int, 2}, bj::Array{Int,1}, CTS::Constants)
    PP=[p for p in 1:CTS.P]
    CC=[c for c in 1:CTS.C]
    common_PP = [0 for p in 1:CTS.P]
    if beta != 0 && beta != 0.0
        for q = 1:CTS.Q
            qc_pos = subset_pos_crane(CTS, q, bj)
            if q == 1
                common_PP = qc_pos
            else
                common_PP = intersect(common_PP, qc_pos)
            end
        end
    end

    model = JuMP.direct_model(Gurobi.Optimizer(OutputFlag=0, Threads=8))

    #if positions p is filled with container i
    @variable(model, w[p=1:CTS.P, i=1:CTS.C], Bin)
    #completion required time to perform task p
    @variable(model, t_task[p=1:CTS.P], lower_bound=0, upper_bound=CTS.H)

    #objective function
    if beta == 0.0 || beta==0
        @objective(model, Min, sum(t_task[p] for p in PP))
    else
        @objective(model, Min, sum(t_task[p] for p in PP) + beta*sum(t_task[p] for p in common_PP))
    end
    #constraints regarding tasks selection (position-container combination)
    @constraint(model, [i=1:CTS.C], sum(w[p,i] for p in subset_pos(PP, task_times, i)) == 1)
    @constraint(model, [p=1:CTS.P], sum(w[p,i] for i in subset_pos(CC, task_times, p)) == 1)

    @constraint(model, [p=1:CTS.P], t_task[p] == sum(task_times[p,i]*w[p,i] for i in subset_pos(CC, task_times, p)))

    #solution
    @time JuMP.optimize!(model) # Old syntax: status = JuMP.solve(model)

    #output
    tasks_by_w = Dict{Int, LTask}()

    for t in findall( x -> x == 1, JuMP.value.(w))
       tasks_by_w[t[1]]=LTask(t[1],bj[t[1]],t[2],task_times[t[1],t[2]])
    end
    return(tasks_by_w)
end


function FlexibleShipLoadingProblem(alpha1::Number, alpha2::Number, prec::Dict{Int, Array}, task_times::Array{Int, 2}, bj::Array{Int,1}, LB::Number, CTS::Constants)
    T=CTS.P+1
    PP=[p for p in 1:CTS.P]
    PPP=[p for p in 0:T]
    PP0=[p for p in 0:CTS.P]
    PPT=[p for p in 1:T]
    QQ=[q for q in 1:CTS.Q]
    CC=[c for c in 1:CTS.C]

    #create bj_init
    bj_init = Array{Int,1}()
    for q in QQ
        push!(bj_init, init_bay(q, CTS))
    end
    #create bj_dict
    bj_dict = Dict{Int, Array{Int,1}}()
    for p in PPP
        l = Array{Int,1}()
        for q in QQ
            if p == 0
                push!(l, bj_init[q])
            elseif p == T
                push!(l, 0)
            else
                push!(l, bj[p])
            end
        end
        bj_dict[p] = l
    end

    #using JuMP, Gurobi
    model = JuMP.direct_model(Gurobi.Optimizer(OutputFlag=0, Threads=8))

    #if positions p, s are performed consecutively by crane q
    @variable(model, x[p=0:T, s=0:T, q=1:CTS.Q], Bin)
    #if positions p is filled with container i
    @variable(model, w[p=0:T, i=1:CTS.C], Bin)
    #if position s starts after the completion time of task p
    @variable(model, z[p=1:CTS.P, s=1:CTS.P], Bin)

    #completion time of task p
    @variable(model, t_load[p=0:T], Int, lower_bound=0, upper_bound=CTS.H)
    #completion required time to perform task p
    @variable(model, t_task[p=0:T], lower_bound=0, upper_bound=CTS.H)
    #completion time of crane q
    @variable(model, t_crane[q=1:CTS.Q], lower_bound=0, upper_bound=CTS.H)

    #objective function
    @objective(model, Min, alpha1*t_load[T] + alpha2*sum(t_crane[q] for q in QQ))

    #constraints for variables initialization and boundaries
    @constraint(model, [p=0:T, q=1:CTS.Q], x[p,p,q] == 0)
    @constraint(model, [p=1:CTS.P], z[p,p] == 0)

    @constraint(model, t_load[0] == 0)
    @constraint(model, t_load[T] >= LB)

    @constraint(model, t_task[0] == 0)
    @constraint(model, t_task[T] == 0)

    @constraint(model, [i=1:CTS.C], w[0,i] == 0)
    @constraint(model, [i=1:CTS.C], w[T,i] == 0)

    #constraints regarding tasks selection (position-container combination)
    @constraint(model, [i=1:CTS.C], sum(w[p,i] for p in subset_pos(PP, task_times, i)) == 1)
    @constraint(model, [p=1:CTS.P], sum(w[p,i] for i in subset_pos(CC, task_times, p)) == 1)

    @constraint(model, [p=1:CTS.P], t_task[p] == sum(task_times[p,i]*w[p,i] for i in subset_pos(CC, task_times, p)))

    #relate crane times and makespan
    @constraint(model, [q=1:CTS.Q], t_crane[q] <= t_load[T])

    #constraints regarding tasks assignment
    @constraint(model, [q=1:CTS.Q], sum(x[0,s,q] for s in PPT) == 1)
    @constraint(model, [q=1:CTS.Q], sum(x[p,T,q] for p in PP0) == 1)

    @constraint(model, [p=1:CTS.P], sum(sum(x[p,s,q] for s in PPT) for q in QQ) == 1)
    for p in PP
        for q in QQ
            @constraint(model, sum(x[s,p,q] for s in PP0) - sum(x[p,s,q] for s in PPT) == 0)
        end
    end

    #constraints regarding tasks assignment (precedences)
    for s in PP
        for p in prec[s]
            @constraint(model, t_load[p] + 2*t_task[s] - t_load[s] <= 0)
            @constraint(model, z[p,s] + z[s,p] == 1)
        end
    end

    #guarante correct calculation of loading times and task assignments
    for p in PPP
        for s in PPP
            for q in setdiff(Set(QQ), Set(subset_crane_pos(CTS, p, bj)), Set(subset_crane_pos(CTS, s, bj)))
                @constraint(model, x[p,s,q]==0)
            end
            if p != s
                for q in QQ
                    @constraint(model, t_load[p] + travel_time(bj_dict[p][q], bj_dict[s][q], CTS) + 2*t_task[s] - t_load[s] <= CTS.H*(1-x[p,s,q]))
                end
            end
        end
    end

    for p in PP
        for s in PP
            if p != s
                @constraint(model, t_load[p] + 2*t_task[s] - t_load[s] <= CTS.H*(1-z[p,s]))
                @constraint(model, t_load[s] - 2*t_task[s] - t_load[p] <= CTS.H*z[p,s])
            end
        end
    end

    #quay cranes initialization (after initial dummy task)
    for s in PPP
        for q in QQ
            @constraint(model, travel_time(bj_dict[0][q], bj_dict[s][q], CTS) + 2*t_task[s] - t_load[s] <= CTS.H*(1-x[0,s,q]))
        end
    end

    #guarantee task assignments and crane clearance
    for p in PP
        for s in PP
            for v in QQ
                for w in QQ
                    if p < s && clearance_travel_time(p, s, v, w, bj_dict, CTS) > 0
                        @constraint(model, sum(x[u,p,v] for u in PP0) + sum(x[u,s,w] for u in PP0) <= 1 + z[p,s] + z[s,p])
                        @constraint(model, t_load[p] + clearance_travel_time(p, s, v, w, bj_dict, CTS) + 2*t_task[s] - t_load[s] <= CTS.H*(3 - z[p,s] - sum(x[u,p,v] for u in PP0) - sum(x[u,s,w] for u in PP0)))
                        @constraint(model, t_load[s] + clearance_travel_time(p, s, v, w, bj_dict, CTS) + 2*t_task[p] - t_load[p] <= CTS.H*(3 - z[s,p] - sum(x[u,p,v] for u in PP0) - sum(x[u,s,w] for u in PP0)))
                    end
                end
            end
        end
    end

    #solution
    @time JuMP.optimize!(model) # Old syntax: status = JuMP.solve(model)
    makespan = JuMP.value.(t_load)[T]

    sol_x = Dict{Int, Array}()
    for q=1:CTS.Q
        for p=0:T
            for s=0:T
                if JuMP.value.(x)[p,s,q] == 1
                    if haskey(sol_x, q) == false
                        sol_x[q] = Array{NamedTuple{(:start_time, :pos, :next_pos, :qc),Tuple{Int64,Int64,Int64,Int64}}, 1}()
                    end
                    push!(sol_x[q], (start_time=JuMP.value.(t_load)[p]-2*JuMP.value.(t_task)[p], pos=p, next_pos=s, qc=q))
                end
            end
        end
        sort!(sol_x[q], by = x->x.start_time)
    end

    sol_w = Dict{Int, Int}()
    for p=1:CTS.P
        for i=1:CTS.C
            if JuMP.value.(w)[p,i] == 1
                sol_w[p] = i
            end
        end
    end
    sol_w[0] = 0
    sol_w[T] = 0

    #compute Loading Sequence
    #return(makespan, get_math_ls(sol_x, sol_w, CTS))
    return(makespan, sol_x, sol_w)
end
