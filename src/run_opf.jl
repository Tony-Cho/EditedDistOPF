# src/run_pf.jl

using PowerModelsDistribution
using Ipopt

function run_opf(eng)
    result = solve_mc_opf(
        eng,
        ACPUPowerModel,
        Ipopt.Optimizer
    )
    return result
end