# demo_vpp_dss.jl - 演示直接从 OpenDSS 加载 VPP 资源

using PowerModelsDistribution
using JSON

dss_path = "data/opendss_case33/Master.dss"

println("========================================")
println("从 OpenDSS 直接加载 VPP 资源演示")
println("========================================")
println()

println("1. 加载包含 VPP 资源的 OpenDSS 模型...")
eng = PowerModelsDistribution.parse_file(dss_path)

println()
println("2. OpenDSS 引擎模型结构:")
println("   - 母线: ", length(eng["bus"]), " 个")
println("   - 线路: ", length(eng["line"]), " 条")
println("   - 负荷: ", length(eng["load"]), " 个")

if haskey(eng, "solar")
    println("   - 光伏: ", length(eng["solar"]), " 个")
else
    println("   - 光伏: 0 个")
end

if haskey(eng, "storage")
    println("   - 储能: ", length(eng["storage"]), " 个")
else
    println("   - 储能: 0 个")
end

println()
println("3. 查看光伏列表:")
if haskey(eng, "solar")

    for (id, gen) in eng["solar"]
        bus_info = haskey(gen, "bus") ? gen["bus"] : "unknown"
        kw_info = haskey(gen, "kw") ? gen["kw"] : (haskey(gen, "pg") ? gen["pg"] : "N/A")
        println("   - $id: bus=$bus_info, kW=$kw_info")
    end
end

println()
println("4. 查看储能列表:")
if haskey(eng, "storage")
    for (id, stor) in eng["storage"]
        bus_info = haskey(stor, "bus") ? stor["bus"] : "unknown"
        kw_info = haskey(stor, "ps") ? stor["ps"] : "N/A"
        println("   - $id: bus=$bus_info, kW=$kw_info")
    end
end

println()
println("5. 转换为数学模型...")
math = PowerModelsDistribution.transform_data_model(eng)

println()
println("6. 数学模型结构:")
println("   - 母线: ", length(math["bus"]), " 个")
println("   - 线路: ", length(math["branch"]), " 条")
println("   - 负荷: ", length(math["load"]), " 个")
println("   - 发电机: ", length(math["gen"]), " 个")

if haskey(math, "storage")
    println("   - 储能: ", length(math["storage"]), " 个")
else
    println("   - 储能: 0 个 (注: 可能被转换为发电机)")
end

println()
println("========================================")
println("演示完成!")
println("========================================")