# EditedDistOPF

```
case33bw.m
│
├── mpc.baseMVA
│       └── Master.dss 中作为注释/基准信息
│
├── mpc.bus
│       ├── bus_i, baseKV
│       │       └── Master.dss 中的电压等级、母线名称
│       └── Pd, Qd
│               └── Loads.dss 中的 kw, kvar
│
├── mpc.branch
│       ├── fbus, tbus
│       │       └── Lines.dss 中的 bus1, bus2
│       ├── r, x
│       │       └── Lines.dss 中的 r1, x1
│       └── status
│               └── Lines.dss 中的 enabled=yes/no
│
└── mpc.gen
        └── Master.dss 中的 Circuit source
```