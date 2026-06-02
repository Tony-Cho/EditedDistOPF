# src/modify_case.jl

function set_voltage_limits!(eng; vmin=0.95, vmax=1.05)
    if haskey(eng, "bus")
        for (_, bus) in eng["bus"]
            bus["vm_lb"] = fill(vmin, 3)
            bus["vm_ub"] = fill(vmax, 3)
        end
    end
    return eng
end

function add_dg!(eng, bus_name; pg_max=0.5, qg_max=0.2)
    # 这里后面可以继续扩展
    return eng
end