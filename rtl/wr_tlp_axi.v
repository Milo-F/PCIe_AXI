module wr_tlp_axi #(
    DOUBLE_WORD             =        32,                                 // 双字
    HEADER_SIZE             =        4*DOUBLE_WORD,                      // TLP Header 4个双字宽度
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD,                      // TLP数据总线宽度256bits
    AXI_DATA_WIDTH          =        TLP_DATA_WIDTH,                     // AXI数据总线宽度256bits
    AXI_ADDR_WIDTH          =        64,                                 // AXI地址总线宽度64bits
    AXI_STRB_WIDTH          =        AXI_DATA_WIDTH/8,                   // AXI数据阀门
    AXI_ID_WIDTH            =        8,                                  // AXI ID宽度
    AXI_MAX_BURST_LEN       =        256                                 // AXI一次Burst传输最大发送次数
) (
    input                                                   clk,
    input                                                   rst_n,
    input       wire        [HEADER_SIZE-1:0]               tlp_hdr,     // 输入TLPheader
    input       wire        [TLP_DATA_WIDTH-1:0]            tlp_data,    // 输入TLP数据
    input       wire                                        tlp_sop,     // 输入TLP开始标识
    input       wire                                        tlp_eop,     // 输入TLP结束标识
    input       wire                                        tlp_valid,
    output      reg                                         tlp_ready,
    output      reg         [AXI_ID_WIDTH-1:0]              axi_awid,    // AXI设备的ID用于识别
    output      reg         [AXI_ADDR_WIDTH-1:0]            axi_awaddr,  // 需要写入数据的地址
    output      reg         [7:0]                           axi_awlen,   // 一次Burts传输的transfer次数 = awlen+1，AXI4最多支持增值式burst传输一次256次tranasfer（AXI3仅支持16次），其他burst类型同样也是16次
    output      reg         [2:0]                           axi_awsize,  // 一次transfer发送的数据字节数，最多一次transfer128个byte，即1024bits数据，若发送的字节数小于数据总线宽度，即位narrow transfer
    output      reg         [1:0]                           axi_awburst, // burst传输的传输类型，包括fixed、inc和wrap，fixed每次transfer写入固定地址、inc每次transfer地址加固定值（取决于transfer数据大小），wrap不清楚，transfer次数只能是2、4、8、16
    output      reg                                         axi_awlock,  // 是否支持带锁的数据，带锁标识独占总线传输
    output      reg         [3:0]                           axi_awcache, // 是否接受来自cache或者buffer的response，w，r，cache，buffer
    output      reg         [2:0]                           axi_awprot,  // 1/0 特权/非特权，不安全/安全，指令/数据访问
    output      reg                                         axi_awvalid,
    input       wire                                        axi_awready,
    output      reg         [AXI_DATA_WIDTH-1:0]            axi_wdata,   // AXI写入数据总线宽度256
    output      reg                                         axi_wvalid,  //
    output      reg         [AXI_STRB_WIDTH-1:0]            axi_wstrb,   // AXI数据有效阀门，其第n位为1代表data[n*8+7:n*8]数据有效
    output      reg                                         axi_wlast,   // 最后一次transfer
    input       wire                                        axi_awready,
    input       wire        [AXI_ID_WIDTH-1:0]              axi_bid,     // 回应ID，要与AWID匹配
    input       wire        [1:0]                           axi_bresp,   // 回应，分为OK，EXOK，SLAVER和DECERR，OKAY是正常成功传输响应，EXOKAY是独占访问下的传输成功响应，SLAVER是传输失败响应，DECODERR是译码错误响应
    input       wire                                        axi_bvalid,
    output      reg                                         axi_bready,
    output      reg                                         tlp_error
);
    // AXI AW
    reg                     [AXI_ID_WIDTH-1:0]              axi_awid_nxt;
    reg                     [AXI_ADDR_WIDTH-1:0]            axi_awaddr_nxt;
    reg                     [7:0]                           axi_awlen_nxt;
    reg                     [2:0]                           axi_awsize_nxt;
    reg                     [1:0]                           axi_awburst_nxt;
    reg                     [3:0]                           axi_awcache_nxt;
    reg                     [2:0]                           axi_awprot_nxt;
    reg                                                     axi_awlock_nxt;
    reg                                                     axi_awvalid;
    // AXI W
    reg                     [AXI_DATA_WIDTH-1:0]            axi_wdata_nxt;
    reg                     [AXI_STRB_WIDTH-1:0]            axi_wstrb_nxt;
    reg                                                     axi_wlast_nxt;
    reg                                                     axi_wvalid;
    // AXI B
    reg                                                     axi_bready_nxt;
    // TLP
    reg                                                     tlp_ready_nxt;
    /*
     * 状态机配置
     */
    // 状态定义
    localparam IDLE      = 3'b001;
    localparam TRANSFER  = 3'b010;
    localparam WAITE_END = 3'b100;
    // 状态索引
    localparam IDLE_IDX      = 0;
    localparam TRANSFER_IDX  = 1;
    localparam WAITE_END_IDX = 2;
    // 状态寄存器
    reg                     [2:0]                           status,status_nxt;
    // 发送子状态机定义
    localparam START    = 2'b0;
    localparam CONTINUE = 2'b1;
    localparam END      = 2'b2;
    reg                     [1:0]                           tr_status,tr_status_nxt;
    
    
endmodule
