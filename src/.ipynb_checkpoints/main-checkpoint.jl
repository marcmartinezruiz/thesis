include("./read_data.jl")
include("./init.jl")
include("./functions.jl")


possible_tasks=[]
tasks_by_position=Dict{Int, Array}()
prec=Dict{Int, Array}()
tasks_time = zeros(Int8, P, C)

for p = 1:P
    l=[]
    for t=1:CP
        #create array with all tasks
        if p==P
            push!(possible_tasks, Task(cpij[t,1]+1, cpij[t,2]+1, cpij[t,3]))
            tasks_time[cpij[t,1]+1, cpij[t,2]+1] = cpij[t,3]
        end
        #create dict with the tasks sorted by position
        if cpij[t,1]+1==p
            push!(l,Task(cpij[t,1]+1, cpij[t,2]+1, cpij[t,3]))
        end
    end
    tasks_by_position[p]=l

    #create dict with the position precedences
    s=[]
    for j = 1:P
        if prejj[p,j]==1
            push!(s,j)
        end
    end
    prec[p]=s

end
