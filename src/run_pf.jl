# src/run_pf.jl

using PowerModelsDistribution
using Ipopt

function run_pf(eng)
    result = solve_mc_pf(
        eng,
        ACPUPowerModel,
        Ipopt.Optimizer
    )
    return result
end