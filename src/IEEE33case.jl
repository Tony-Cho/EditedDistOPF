using PowerModels
using Ipopt

data = PowerModels.parse_file("case33bw.m")

result = PowerModels.solve_opf(
    data,
    ACPPowerModel,
    Ipopt.Optimizer
)

println("Termination status: ", result["termination_status"])
println("Objective value: ", result["objective"])