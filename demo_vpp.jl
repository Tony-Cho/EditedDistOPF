# demo_vpp.jl - VPP 虚拟电厂优化演示
# VPP 资源从 OpenDSS 文件加载

using PowerModelsDistribution
using Ipopt
using JuMP
using JSON
using InfrastructureModels
const IM = InfrastructureModels

dss_path = "data/opendss_case33/Master.dss"

println("========================================")
println("VPP 虚拟电厂优化演示")
println("========================================")
println()

println("1. 加载配电网模型...")
eng = PowerModelsDistribution.parse_file(dss_path)

println("2. 原始模型数据结构:")
println("   - 母线数: ", length(eng["bus"]))
println("   - 线路数: ", length(eng["line"]))
println("   - 负荷数: ", length(eng["load"]))
println("   - 电压源数: ", length(eng["voltage_source"]))

# 统计从 OpenDSS 加载的 VPP 资源
solar_count = haskey(eng, "solar") ? length(eng["solar"]) : 0
storage_count = haskey(eng, "storage") ? length(eng["storage"]) : 0
println("   - 光伏 (solar): $solar_count 个")
println("   - 储能 (storage): $storage_count 个")

println()
println("3. 检查 VPP 资源...")
if solar_count > 0
    println("  光伏列表:")
    for (id, solar) in eng["solar"]
        bus = solar["bus"]
        ps = haskey(solar, "ps") ? solar["ps"] : "N/A"
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

println()
println("4. 转换为数学模型...")
math = PowerModelsDistribution.transform_data_model(eng)

println("5. 数学模型数据结构:")
println("   - 母线数: ", length(math["bus"]))
println("   - 线路数: ", length(math["branch"]))
println("   - 负荷数: ", length(math["load"]))
println("   - 发电机数: ", length(math["gen"]))

println()
println("6. 构建并求解 VPP OPF...")

pm = IM.instantiate_model(
    math,
    PowerModelsDistribution.ACPUPowerModel,
    PowerModelsDistribution.build_mc_opf,
    PowerModelsDistribution.ref_add_core!,
    Set{String}(),
    :pmd,
)

model = pm.model
pg = PowerModelsDistribution.var(pm, :pg)
qg = PowerModelsDistribution.var(pm, :qg)

println("   发电机变量: ", keys(pg))

@objective(model, Min, sum(pg[1][c] for c in 1:3))

result = PowerModelsDistribution.optimize_model!(pm, optimizer = Ipopt.Optimizer)

println()
println("7. 优化结果:")
println("   - 终止状态: ", result["termination_status"])
println("   - 目标函数值: ", result["objective"])

if haskey(result["solution"], "bus")
    println()
    println("8. 关键节点电压:")
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
    println("9. 光伏 (solar) 出力:")
    for (id, sol) in result["solution"]["solar"]
        ps = sol["ps"]
        p_total = round(sum(ps), digits=4)
        println("   $id: P = $p_total MW (发电)")
    end
end

# 输出储能结果
if haskey(result["solution"], "storage")
    println()
    println("10. 储能 (storage) 出力:")
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

println()
println("========================================")
println("保存结果到文件...")
println("========================================")

open("result/vpp_opf_result.json", "w") do f
    JSON.print(f, result, 2)
end

println("结果已保存到 result/vpp_opf_result.json")
println()
println("演示完成!")
