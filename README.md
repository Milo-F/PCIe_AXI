# Memory transaction PCIe to AXI bridge
&emsp;&emsp;实现从将PCIe收到的存储器读写请求TLP拆解转化为AXI总线格式实现PCIe读写AXI存储设备，包含TLP解复用模块、读转换模块、写转换模块及顶层模块。
## 环境
&emsp;&emsp;设计所使用的软件环境为 Synopsys 公司的用于数字设计的软件集合，包括编译使用的 VCS 、波形仿真使用的 Verdi 、综合以及时序面积约束使用的 Design Compiler 、 STA 使用的 Prime Time 以及形式验证所使用的 Formality 。整个软件环境配置在 WSL2 的 ubuntu 子系统中，并使用 vscode remote 链接运行。
## 文件说明
### 模块说明
&emsp;&emsp;所有的 module 设计代码都保存在 [src/rtl]( ./src/rtl/) 目录下，包括：
1. [pcie_axi_m.v](./src/rtl/pcie_axi_m.v): 顶层模块，连接了pcie TLP通道与AXI总线通道，在内部连接了TLP解复用器、读/写解析模块；
2. [tlp_demux.v](./src/rtl/tlp_demux.v): 将TLP Request通过FMT与Type关键字进行筛选，剔除错误的TLP请求，并将读TLP与写TLP剥离分别送至读TLP解析模块与写TLP解析模块；
3. [rd_tlp_axi.v](./src/rtl/rd_tlp_axi.v): Memory Read TLP解析模块，将存储器读Request解析其地址，数据荷载长度，数据使能等，并转化并产生AXI AR通道对应控制信号，实现AXI读请求的发送，并将AXI R通道读取到的数据按照PCIe RCB对齐产生CPLD，返回到PCIe TLP通道；
4. [wr_tlp_axi.v](./src/rtl/wr_tlp_axi.v): Memory Write TLP解析模块，将存储器写Request解析其地址、数据、数据阀门等信息，通过FIFO缓存要写入的数据，转化并产生对应的AXI AW通道控制信号，将数据通过AXI W通道写入AXI存储设备；
5. [syn_fifo.v](./src/rtl/syn_fifo.v): 同步fifo，缓存待写入AXI存储的数据；
6. [fifo_ram.v](./src/rtl/fifo_ram.v): fifo使用的仿真ram存储单元。

## Memory Read Request 时序
![read_request时序](./figures/pcie_read%E6%97%B6%E5%BA%8F.jpg)