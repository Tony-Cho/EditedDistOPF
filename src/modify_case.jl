# src/modify_case.jl

import PowerModelsDistribution as PMD
import InfrastructureModels as IM
using Ipopt
using JuMP

function run_custom_opf(eng)
    # 1. transform to MATHEMATICAL model
    math = transform_data_model(eng)

    # ========== 第一次优化：最大化根节点注入功率 ==========
    # 生成 PowerModelsDistribution / JuMP model
    pm_max = IM.instantiate_model(
        math,
        PMD.ACPUPowerModel,
        PMD.build_mc_opf,  
        PMD.ref_add_core!,
        Set{String}(),
        :pmd,
    )

    # 获取节点注入有功功率变量
    pg_max = PMD.var(pm_max, :pg)
    
    # 设置目标函数为最大化根节点(bus1)的注入有功功率
    @objective(pm_max.model, Max, sum(pg_max[1][c] for c in 1:3))

    # 求解
    result_max = optimize_model!(
        pm_max,
        optimizer = Ipopt.Optimizer
    )

    # ========== 第二次优化：最小化根节点注入功率 ==========
    # 重新构建模型（JuMP不允许在优化后直接修改目标函数）
    pm_min = IM.instantiate_model(
        math,
        PMD.ACPUPowerModel,
        PMD.build_mc_opf,  
        PMD.ref_add_core!,
        Set{String}(),
        :pmd,
    )

    # 获取节点注入有功功率变量
    pg_min = PMD.var(pm_min, :pg)
    
    # 设置目标函数为最小化根节点(bus1)的注入有功功率
    @objective(pm_min.model, Min, sum(pg_min[1][c] for c in 1:3))

    # 求解
    result_min = optimize_model!(
        pm_min,
        optimizer = Ipopt.Optimizer
    )

    return result_max, result_min
end
