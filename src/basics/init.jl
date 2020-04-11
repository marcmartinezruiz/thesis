struct Constants
    C::Int
    P::Int
    J::Int
    Q::Int
    H::Int
    tt::Int
    delta::Int
end

mutable struct Timer
    period::Int
    horizon_plan::Int
    available_cranes::Array{Int, 1}
end

struct Task
    p::Int
    b::Int
    c::Int
    t::Int
end

mutable struct LoadingSequence
    order::Array{NamedTuple{(:task, :start_time, :qc),Tuple{Task,Int,Int}}, 1}
    tasks_left::Int
    len::Int
    filled_pos::Array{Int, 1}
    loaded_cont::Array{Int, 1}
end

mutable struct QuayCrane
    q::Int
    available_bays::Array{Int, 1}
    status::String
    time_left::Int
    current_bay::Int
    next_bay::Int
    task_buffer::Array{Task, 1}
end

function init_timer(CTS::Constants)
    TIME = Timer(0, CTS.H, collect(1:Q))
    return(TIME)
end

function init_ls(CTS::Constants)
    LS = LoadingSequence([], CTS.P, 0, [], [])
    return(LS)
end

#init all QC, where qj=data_matrix and current_bay=top_left(qj)
function init_qc(CTS::Constants)
    QC=Array{QuayCrane, 1}()
    for q = 1:CTS.Q
        qc_pos = subset_bay(CTS, q)
        push!(QC, QuayCrane(q, qc_pos, "idle", 0, minimum(qc_pos), minimum(qc_pos), Array{Task, 1}()))
    end
    return(QC)
end

function Base.show(io::IO, LS::LoadingSequence)
    println(io, "LOADING SEQUENCE")
    println(io, "- tasks_left: ", LS.tasks_left)
    println(io, "- filled_pos: ", LS.filled_pos)
    println(io, "- loaded_cont: ", LS.loaded_cont)
    for i = 1:length(LS.order)
        print(io, "  "*string(i)*". ")
        println(io, LS.order[i])
    end
end

function Base.show(io::IO, ::MIME"text/plain", QC::QuayCrane)
    println(io, "QUAY CRANE - "*string(QC.q))
    println(io, " - status: ", QC.status)
    println(io, " - time_left: ", QC.time_left)
    println(io, " - current_bay: ", QC.current_bay)
    println(io, " - next_bay: ", QC.next_bay)
    println(io, " - task_buffer: ", QC.task_buffer)
    println(io, " - available_bays: ", QC.available_bays)
    println("\n")
end

function Base.show(io::IO, QC::QuayCrane)
    println(io, string(QC.q)*". QUAY CRANE")
    println(io, " - status: ", QC.status)
    println(io, " - time_left: ", QC.time_left)
    println(io, " - current_bay: ", QC.current_bay)
    println(io, " - next_bay: ", QC.next_bay)
    println(io, " - task_buffer: ", QC.task_buffer)
    println(io, " - available_bays: ", QC.available_bays)
    println("\n")
end

function Base.show(io::IO, TIME::Timer)
    println("--------------")
    println(io, "TIME PERIOD: ", TIME.period)
    println(io, " - available cranes: ", TIME.available_cranes)
    println("--------------")
end
