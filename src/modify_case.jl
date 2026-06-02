# src/modify_case.jl

import PowerModelsDistribution as PMD
import InfrastructureModels as IM
using Ipopt
using JuMP

function run_custom_opf(eng)
    # 1. transform to MATHEMATICAL model
    math = transform_data_model(eng)

    # 2. generate PowerModelsDistribution / JuMP model
    pm = IM.instantiate_model(
        math,
        PMD.ACPUPowerModel,
        PMD.build_mc_opf,  
        PMD.ref_add_core!,
        Set{String}(),
        :pmd,
        # ref_extensions = [PMD.ref_add_arcs_trans!],
    )

    print(pm.model)

    # 3. modify JuMP model
    model = pm.model

    # 4. add your own constraints / objective function
    # @objective(model, Min,
    #     sum((vm[i][c] - 1.0)^2 for i in keys(vm) for c in eachindex(vm[i]))
    # )

    # 5. solve
    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end