# src/run_vpp_opf.jl
# VPP 虚拟电厂优化函数库

import PowerModelsDistribution as PMD
import InfrastructureModels as IM
using Ipopt
using JuMP

"""
    add_vpp_resources!(eng)

说明：VPP 资源（光伏和储能）应直接在 OpenDSS 文件中定义，
然后通过 PowerModelsDistribution.parse_file() 自动加载。
此函数用于展示已加载的资源信息。
"""
function add_vpp_resources!(eng)
    println("检查 VPP 资源...")
    
    # 统计从 OpenDSS 文件加载的资源
    solar_count = haskey(eng, "solar") ? length(eng["solar"]) : 0
    storage_count = haskey(eng, "storage") ? length(eng["storage"]) : 0
    
    println("  - 光伏 (solar): $solar_count 个")
    println("  - 储能 (storage): $storage_count 个")
    
    if solar_count > 0
        println("  光伏列表:")
        for (id, solar) in eng["solar"]
            bus = solar["bus"]
            ps = haskey(solar, "pg") ? solar["pg"] : "N/A"
            println("    - $id: bus=$bus, ps=$ps")
        end
    end
    
    if storage_count > 0
        println("  储能列表:")
        for (id, storage) in eng["storage"]
            bus = storage["bus"]
            ps = haskey(storage, "ps") ? storage["ps"] : "N/A"
            println("    - $id: bus=$bus, ps=$ps")
        end
    end
    
    return eng
end

"""
    run_vpp_opf(eng)

运行 VPP 虚拟电厂最优潮流优化
"""
function run_vpp_opf(eng)
    println("\n转换数据模型...")
    math = PMD.transform_data_model(eng)
    
    println("构建优化模型...")
    pm = IM.instantiate_model(
        math,
        PMD.ACPUPowerModel,
        PMD.build_mc_opf,
        PMD.ref_add_core!,
        Set{String}(),
        :pmd,
    )
    
    model = pm.model
    
    # 获取变量
    pg = PMD.var(pm, :pg)
    qg = PMD.var(pm, :qg)
    
    # 打印可用变量信息
    println("   发电机数量: ", length(pg))
    
    # 设置目标函数: 最小化根节点(bus1)注入功率
    @objective(model, Min, sum(pg[1][c] for c in 1:3))
    
    println("   目标函数: 最小化根节点注入功率")
    result = PMD.optimize_model!(pm, optimizer = Ipopt.Optimizer)
    
    return result
end

function run_vpp_demo(dss_path)
    
    println("========================================")
    println("VPP 虚拟电厂优化演示")
    println("========================================")
    println()
    
    println("1. 加载配电网模型...")
    eng = PMD.parse_file(dss_path)
    
    println("2. 原始模型数据结构:")
    println("   - 母线数: ", length(eng["bus"]))
    println("   - 线路数: ", length(eng["line"]))
    println("   - 负荷数: ", length(eng["load"]))
    
    println()
    println("3. 检查 VPP 资源...")
    add_vpp_resources!(eng)
    
    println()
    println("4. 运行 VPP OPF 优化...")
    
    result = run_vpp_opf(eng)
    
    println()
    println("5. 优化结果:")
    println("   - 终止状态: ", result["termination_status"])
    println("   - 目标函数值: ", result["objective"])
    
    if haskey(result["solution"], "bus")
        println()
        println("6. 关键节点电压:")
        for i in ["1", "10", "15", "20", "25", "30"]
            if haskey(result["solution"]["bus"], i)
                bus = result["solution"]["bus"][i]
                vm = bus["vm"]
                println("   Bus $i: Vm = [$(round(vm[1], digits=4)), $(round(vm[2], digits=4)), $(round(vm[3], digits=4))] pu")
            end
        end
    end
    
    # 输出光伏结果
    if haskey(result["solution"], "solar")
        println()
        println("7. 光伏 (solar) 出力:")
        for (id, sol) in result["solution"]["solar"]
            ps = sol["ps"]
            p_total = round(sum(ps), digits=4)
            println("   $id: P = $p_total MW")
        end
    end
    
    # 输出储能结果
    if haskey(result["solution"], "storage")
        println()
        println("8. 储能 (storage) 出力:")
        for (id, stor) in result["solution"]["storage"]
            ps = stor["ps"]
            p_total = round(sum(ps), digits=4)
            if p_total < 0
                println("   $id: 放电 P = $(abs(p_total)) MW")
            elseif p_total > 0
                println("   $id: 充电 P = $p_total MW")
            else
                println("   $id: 待机 P = 0 MW")
            end
        end
    end
    
    return result
end