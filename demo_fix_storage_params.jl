# demo_fix_storage_params.jl
# 演示如何修改 eng 模型中不被支持的参数

using PowerModelsDistribution
using Ipopt
using JuMP
using InfrastructureModels
const IM = InfrastructureModels

dss_path = "data/opendss_case33/Master.dss"

println("========================================")
println("修改 eng 模型参数示例")
println("========================================")
println()

# =========================================
# 第1步：加载 OpenDSS 文件
# =========================================
println("1. 加载 OpenDSS 文件...")
eng = PowerModelsDistribution.parse_file(dss_path)

# =========================================
# 第2步：查看当前 eng 模型中的参数
# =========================================
println()
println("2. 当前 eng 模型参数:")
println()

# 查看储能参数
if haskey(eng, "storage")
    for (id, storage) in eng["storage"]
        println("  储能 $id:")
        println("    ps: $(storage["ps"])")
        println("    energy: $(storage["energy"])")
        println("    energy_ub: $(storage["energy_ub"])")
        if haskey(storage, "charge_efficiency")
            println("    charge_efficiency: $(storage["charge_efficiency"])")
        else
            println("    charge_efficiency: 未定义 (使用默认值)")
        end
    end
end

# =========================================
# 第3步：修改 eng 模型中的参数
# =========================================
println()
println("3. 修改 eng 模型参数...")

# 修改储能参数
if haskey(eng, "storage")
    for (id, storage) in eng["storage"]
        # 修改效率参数 (PowerModels期望0.0-1.0范围，不是百分比)
        if haskey(storage, "charge_efficiency")
            storage["charge_efficiency"] = 0.95  # 95% = 0.95
            println("  - $id: charge_efficiency = 0.95")
        end
        
        if haskey(storage, "discharge_efficiency")
            storage["discharge_efficiency"] = 0.95  # 95% = 0.95
            println("  - $id: discharge_efficiency = 0.95")
        end
        
        # 修改能量参数
        if haskey(storage, "energy")
            # 假设当前 energy_ub = 1000, 设置 SOC = 50%
            storage["energy"] = storage["energy_ub"] * 0.5
            println("  - $id: energy = $(storage["energy"]) (50% SOC)")
        end
        
        # 修改充放电功率限制
        if haskey(storage, "charge_ub")
            storage["charge_ub"] = storage["ps"]  # 如果 ps 是额定功率
            println("  - $id: charge_ub = $(storage["charge_ub"])")
        end
        
        if haskey(storage, "discharge_ub")
            storage["discharge_ub"] = storage["ps"]
            println("  - $id: discharge_ub = $(storage["discharge_ub"])")
        end
    end
end

# 修改光伏参数
if haskey(eng, "solar")
    for (id, solar) in eng["solar"]
        println()
        println("  光伏 $id:")
        
        # 修改功率因数
        if haskey(solar, "pf")
            solar["pf"] = 0.95  # 滞后功率因数
            println("    - pf = 0.95")
        end
        
        # 修改有功功率设定
        if haskey(solar, "ps")
            # 注意：ps 负值表示发电
            original_ps = solar["ps"]
            solar["ps"] = original_ps * 0.8  # 80% 出力
            println("    - ps = $(solar["ps"]) (原值: $original_ps)")
        end
    end
end

# =========================================
# 第4步：转换为数学模型并优化
# =========================================
println()
println("4. 转换为数学模型...")
math = PowerModelsDistribution.transform_data_model(eng)

println()
println("5. 构建并求解 OPF...")

pm = IM.instantiate_model(
    math,
    PowerModelsDistribution.ACPUPowerModel,
    PowerModelsDistribution.build_mc_opf,
    PowerModelsDistribution.ref_add_core!,
    Set{String}(),
    :pmd,
)

model = pm.model
pg = PMD.var(pm, :pg)

@objective(model, Min, sum(pg[1][c] for c in 1:3))

result = PowerModelsDistribution.optimize_model!(pm, optimizer = Ipopt.Optimizer)

println()
println("6. 优化结果:")
println("   - 终止状态: ", result["termination_status"])
println("   - 目标函数值: ", result["objective"])

println()
println("========================================")
println("演示完成!")
println("========================================")
