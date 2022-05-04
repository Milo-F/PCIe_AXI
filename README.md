# Memory transaction PCIe to AXI bridge
&emsp;&emsp;实现从将PCIe收到的存储器读写请求TLP拆解转化为AXI总线格式实现PCIe读写AXI存储设备，包含TLP解复用模块、读转换模块、写转换模块及顶层模块。