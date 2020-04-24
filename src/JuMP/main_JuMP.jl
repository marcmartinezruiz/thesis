include("../input_data/read_data.jl")
include("../basics/init.jl")
include("../input_data/data_manipulation.jl")
#include("../src/functions.jl")

possible_tasks = Array{Task, 1}()
tasks_by_position = Dict{Int, Array}()
prec = Dict{Int, Array}()
task_times = zeros(Int, P, C)

for p = 1:P
    l=[]
    for t=1:CP
        target_bay = bj[cpij[t,1]+1]
        if p==P
            #create array with all tasks
            push!(possible_tasks, Task(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
            #create matrix with all task times
            task_times[cpij[t,1]+1, cpij[t,2]+1] = cpij[t,3]
        end
        #create dict with the tasks sorted by position
        if cpij[t,1]+1==p
            push!(l,Task(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
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

H = horizon_plan(C,P,J,Q,tt,d,tasks_by_position)
CTS = Constants(C,P,J,Q,H,tt,d)
