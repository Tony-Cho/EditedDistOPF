# src/postprocess.jl

using JSON

function save_result(path::String, result)
    open(path, "w") do io
        JSON.print(io, result, 4)
    end
end

function print_summary(result)
    println("Termination status: ", result["termination_status"])

    if haskey(result, "objective")
        println("Objective value: ", result["objective"])
    end
end