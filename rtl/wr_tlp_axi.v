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
    input       wire                                        axi_wready,
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
    reg                                                     axi_awvalid_nxt;
    // AXI W
    reg                     [AXI_DATA_WIDTH-1:0]            axi_wdata_nxt;
    reg                     [AXI_STRB_WIDTH-1:0]            axi_wstrb_nxt;
    reg                                                     axi_wlast_nxt;
    reg                                                     axi_wvalid_nxt;
    // AXI B
    reg                                                     axi_bready_nxt;
    // TLP
    reg                                                     tlp_ready_nxt;
    // TLP header 解析
    wire                    [2:0]                           hdr_fmt;    // 1/0 fmt[1]:with data(Wr)/no data(Rd); fmt[0] 4DW/3DW; fmt:100 prefix
    wire                    [4:0]                           hdr_type;    // 00000 memory TLP
    wire                    [2:0]                           hdr_tc;    // 优先级控制，支持QoS的PCIe设备对于每种不同的TLP传输有不同的VCbuffer
    wire                    [2:0]                           hdr_attr;    //attr[2]在tc后面，用于控制ID-based ordering；attr[1:0]用于控制是否支持relax ordering用于支持PCI-X设备。
    wire                                                    hdr_ln;    // Lightweight Notification模式，轻量级通知，通过EP注册主机的cacheline并复制数据到自己的cache实现降低延迟PCIe4.0引入，6.0取消，
    wire                                                    hdr_th;    // 标识TLP processing hints（TPH）的存在，就是header的最低2位ph
    wire                                                    hdr_td;    // 标识digest的存在
    wire                                                    hdr_ep;    // 标识数据无效
    wire                    [1:0]                           hdr_at;    // 标识地址类型，00默认不翻译，01需要翻译，10已经翻译过了，11保留
    wire                    [10:0]                          hdr_length;    // [9:0] 标识携带的数据长度，最多1024DW，最少1DW
    wire                    [15:0]                          hdr_req_id;
    wire                    [9:0]                           hdr_tag;
    wire                    [7:0]                           hdr_first_be;
    wire                    [7:0]                           hdr_last_be;
    wire                    [63:0]                          hdr_addr;
    wire                    [1:0]                           hdr_ph;    // processing hints,标识数据访问模式，00，双向，01，由ep发起request，10，由host发起读写，11，由host发起读写且高临时性
    assign hdr_fmt      = tlp_hdr[127:125];
    assign hdr_type     = tlp_hdr[124:120];
    assign hdr_tc       = tlp_hdr[118:116];
    assign hdr_attr     = {tlp_hdr[114], tlp_hdr[109:108]};
    assign hdr_ln       = tlp_hdr[113];
    assign hdr_th       = tlp_hdr[112];
    assign hdr_td       = tlp_hdr[111];
    assign hdr_ep       = tlp_hdr[110];
    assign hdr_at       = tlp_hdr[107:106];
    assign hdr_length   = {tlp_hdr[105:96] == 10'b0, tlp_hdr[105:96]};
    assign hdr_req_id   = tlp_hdr[95:80];
    assign hdr_tag      = {tlp_hdr[119], tlp_hdr[116], tlp_hdr[79:72]};
    assign hdr_last_be  = tlp_hdr[71:68];
    assign hdr_first_be = tlp_hdr[67:64];
    assign hdr_addr     = hdr_fmt[0] ? {tlp_hdr[63:2], 2'b0} : {32'b0,tlp_hdr[31:2],2'b0}; // 分为4DW和3DW对应于64位地址和32位地址
    assign hdr_ph       = hdr_fmt[0] ? tlp_hdr[1:0] : tlp_hdr[33:32];
    
    // 内部fifo控制信号
    wire                                                    is_full;
    reg                                                     w_en;
    wire                                                    is_empty;
    reg                                                     r_en,r_en_nxt;
    wire                                                    effc_tlp_valid;    // 有效tlp使能
    
    reg                                                     start_tx,start_tx_tmp,start_tx_nxt;
    /*
     * 接收状态机配置
     */
    localparam RX_BUSY            = 2'b0;
    localparam RX_WAITE           = 2'b01;
    localparam RX_STORE_LAST      = 2'b10;
    localparam AXI_BURST_ADDR_INC = $clog2(AXI_DATA_WIDTH / DOUBLE_WORD); // 256/32 = 8 log8 = 3
    reg                     [1:0]                           rx_status,rx_status_nxt;
    reg                     [AXI_BURST_ADDR_INC-1:0]        addr_offset,addr_offset_nxt;    // 非对齐地址的偏移
    reg                     [AXI_DATA_WIDTH-1:0]            data_to_fifo;
    reg                     [TLP_DATA_WIDTH-1:0]            tlp_data_in,tlp_data_in_nxt;
    reg                     [HEADER_SIZE-1:0]               tlp_hdr_in,tlp_hdr_in_nxt;
    always @* begin // 解析tlp header，产生必要的AXI控制信号，将TLP数据对齐存入FIFO
        rx_status_nxt   = rx_status;
        tlp_ready_nxt   = tlp_ready;
        tlp_data_in_nxt = tlp_data_in;
        tlp_hdr_in_nxt  = tlp_hdr_in;
        start_tx_nxt    = start_tx_tmp;
        addr_offset_nxt = addr_offset;
        //
        w_en = tlp_valid & tlp_ready;
        case (rx_status)
            RX_BUSY: begin // 接收TLP包
                tlp_ready_nxt   = (~is_full) & (~tlp_ready);
                addr_offset_nxt = hdr_addr[AXI_BURST_ADDR_INC+2-1:2]; // 4:2,表示以DW存储的非对齐地址偏移
                if (!is_full) begin // 如果FIFO没满,表示可以接收数据
                    if (tlp_ready & tlp_valid) begin // 输入数据有效
                        if (tlp_sop) begin // 如果输入的是第一个数据，则进行AXI总线配置
                            // 保存该帧的hdr信息
                            tlp_hdr_in_nxt = tlp_hdr;
                            start_tx_nxt   = 1'b1;   // AXI开始发送
                        end
                        // 最后一个TLP包，如果是非对齐地址数据，还需要额外存一次数据进fifo
                        if (tlp_eop) begin
                            tlp_ready_nxt = 0;
                            rx_status_nxt = (addr_offset == 0) ? RX_WAITE : RX_STORE_LAST; // 若地址对齐直接等待AXI结束，若非对齐则需要额外将最后一半数据存到fifo中
                        end
                        tlp_data_in_nxt = tlp_data;
                        data_to_fifo    = {tlp_data,tlp_data_in}>>((AXI_BURST_ADDR_INC - addr_offset_nxt)<<5);
                    end
                end
            end
            RX_STORE_LAST: begin
                if (!is_full) begin // 将最后一半数据存进fif o
                    w_en          = 1;
                    data_to_fifo  = {tlp_data_in,{TLP_DATA_WIDTH{1'b0}}}>>((AXI_BURST_ADDR_INC - addr_offset_nxt)<<5);
                    rx_status_nxt = RX_WAITE;
                end
            end
            RX_WAITE: begin // 等待AXI发送结束
                tlp_ready_nxt = 0;
                w_en          = 0;
                if (start_tx) begin
                    rx_status_nxt = RX_WAITE;
                end
                else begin
                    rx_status_nxt = RX_BUSY;
                end
            end
            default:;
        endcase
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_status    <= RX_WAITE;
            start_tx_tmp <= 0;
            start_tx     <= 0;
            tlp_ready    <= 0;
            tlp_data_in  <= 0;
            tlp_hdr_in   <= 0;
            addr_offset  <= 0;
        end
        else begin
            rx_status    <= rx_status_nxt;
            tlp_ready    <= tlp_ready_nxt;
            tlp_data_in  <= tlp_data_in_nxt;
            tlp_hdr_in   <= tlp_hdr_in_nxt;
            start_tx_tmp <= start_tx_nxt;
            start_tx     <= start_tx_tmp;
            addr_offset  <= addr_offset_nxt;
        end
    end
    
    /*
     * 发送状态机配置
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
    localparam START_TR    = 2'b0;
    localparam CONTINUE_TR = 2'b1;
    // localparam IDLE_TR  = 2'b2;
    reg                     [1:0]                           tr_status,tr_status_nxt;
    wire                    [AXI_DATA_WIDTH-1:0]            data_to_axi;
    localparam AXI_TR_MAX_TIMES = 1024/AXI_DATA_WIDTH*DOUBLE_WORD; // 最多需要的AXI传输次数
    localparam AXI_TR_CNT_WIDTH = $clog2(AXI_TR_MAX_TIMES)+1; // 比如128次需要9位计数
    localparam AXI_DW_WIDTH     = AXI_DATA_WIDTH/DOUBLE_WORD; // 256/32     = 8
    localparam AXI_DW_WIDTH_LOG = $clog2(AXI_DW_WIDTH);
    reg                     [AXI_TR_CNT_WIDTH-1:0]          axi_tr_cnt,axi_tr_cnt_nxt;    // AXI发送计数器，数据传输需求次数超过256次就要分多次burst传输。
    wire                    [AXI_TR_CNT_WIDTH-1:0]          axi_tr_cnt_minus1;
    reg                     [8:0]                           burst_cnt,burst_cnt_nxt;    // 单次burst传输的计数器
    wire                    [8:0]                           burst_cnt_minus1;
    assign burst_cnt_minus1  = burst_cnt - 1'b1;
    assign axi_tr_cnt_minus1 = axi_tr_cnt - 1'b1;
    wire                    [AXI_ADDR_WIDTH-1:0]            hdr_lock_addr;
    wire                    [10:0]                          hdr_lock_length;
    reg                     [AXI_BURST_ADDR_INC - 1:0]      offset_lock,offset_lock_nxt;
    assign hdr_lock_length = {tlp_hdr_in[105:96] == 10'b0, tlp_hdr_in[105:96]};
    assign hdr_lock_addr   = tlp_hdr_in[125] ? {tlp_hdr_in[63:2], 2'b0} : {32'b0,tlp_hdr_in[31:2],2'b0}; // 分为4DW和3DW对应于64位地址和32位地址
    // 状态转移，控制数据从fifo到axi的发送状态
    always @* begin // 从FIFO中取出数据发送AXI，根据tlp_header产生AXI控制信号，以及控制burst传输次数
        status_nxt      = status;
        tr_status_nxt   = tr_status;
        axi_tr_cnt_nxt  = axi_tr_cnt;
        burst_cnt_nxt   = burst_cnt;
        offset_lock_nxt = offset_lock;
        r_en_nxt        = r_en;
        // axi aw
        axi_awid_nxt    = 0;
        axi_awaddr_nxt  = axi_awaddr;
        axi_awlen_nxt   = axi_awlen;
        axi_awsize_nxt  = $clog2(AXI_DATA_WIDTH/8); // 256/8  = 32 2^5 101
        axi_awburst_nxt = 2'b01; // inc burst type
        axi_awlock_nxt  = 1'b0; // unlock
        axi_awcache_nxt = 4'b0011; // cacheable and bufferable but unallocatable
        axi_awprot_nxt  = 3'b101; // noprivilage unsafe and data transfer
        axi_awvalid_nxt = axi_awvalid;
        
        // axi w
        axi_wdata_nxt  = axi_wdata;
        axi_wstrb_nxt  = axi_wstrb;
        axi_wlast_nxt  = axi_wlast;
        axi_wvalid_nxt = axi_wvalid;
        
        case (1'b1)
            status[IDLE_IDX]: begin // 空闲等待状态 配置axi_awlen,axi_awaddr
                axi_awaddr_nxt  = hdr_lock_addr;
                axi_tr_cnt_nxt  = (hdr_lock_length >> AXI_DW_WIDTH_LOG)+1'b1;
                offset_lock_nxt = hdr_lock_addr[AXI_BURST_ADDR_INC+2-1:2]; // 4:2,表示以DW存储的非对齐地址偏移
                // 配置awlen，如果需要的发送次数超过了256，则需要多次burst传输，
                if (axi_tr_cnt_nxt <= 256) begin
                    axi_awlen_nxt = (hdr_lock_length >> AXI_DW_WIDTH_LOG); // 需要几次传几次
                    burst_cnt_nxt = axi_tr_cnt_nxt;
                end
                else begin
                    axi_awlen_nxt = 8'hff; // 256次传满
                    burst_cnt_nxt = 9'h100;
                end
                //
                if (start_tx) begin // 开始发送
                    axi_awvalid_nxt = 1'b1;
                    status_nxt      = TRANSFER;
                    tr_status_nxt   = START_TR; // 发送子状态机标识为开始发送
                end
            end
            status[TRANSFER_IDX]: begin
                if (axi_awready & axi_awvalid) begin
                    axi_awvalid_nxt = 1'b0;
                end
                //
                if (!is_empty) begin // 只有当fif o非空，才可以读取数据进行发送
                    case (tr_status)
                        START_TR: begin
                            r_en_nxt = 1'b1;
                            if (r_en) begin // 读取数据
                                r_en_nxt       = 0;
                                axi_wdata_nxt  = data_to_axi;
                                axi_wstrb_nxt  = {{AXI_STRB_WIDTH{1'b1}},{(offset_lock<<2){1'b0}}}; // 第一个数据的数据阀门
                                axi_wvalid_nxt = 1'b1;
                                axi_wlast_nxt  = (burst_cnt == 1);
                            end
                            
                            if (burst_cnt == 1) begin // 如果一次发送就结束了
                                if (axi_wready & axi_wvalid) begin // 数据被接收后
                                    // tr_status_nxt = IDLE_TR; // 发送完毕，转为空闲
                                    start_tx_nxt     = 0; // 停止发送
                                    status_nxt       = WAITE_END; // 转为等待
                                    axi_wvalid_nxt   = 1'b0; // 清除标志位
                                    axi_wlast        = 0;
                                end
                            end
                            else begin
                                if (axi_wready & axi_wvalid) begin
                                    tr_status_nxt  = CONTINUE_TR; // 继续发送
                                    axi_wvalid_nxt = 1'b0; // 清除标志位
                                    burst_cnt_nxt  = burst_cnt_minus1;// 发送计数器-1
                                    axi_tr_cnt_nxt = axi_tr_cnt_minus1; // 总计数器-1
                                end
                            end
                        end
                        CONTINUE_TR: begin
                            if (burst_cnt == 0) begin // 该次burst发送完了
                                if (axi_tr_cnt == 0) begin
                                    start_tx_nxt = 0;
                                    status_nxt   = WAITE_END;
                                end
                                else begin // 一次burst不足以发送整个TLP数据,继续发，修改地址，重发aw控制信号
                                    axi_awaddr_nxt = axi_awaddr + AXI_DATA_WIDTH/8; // 更新下一次burst地址
                                    // 更新下一次burst len
                                    if (axi_tr_cnt <= 256) begin
                                        axi_awlen_nxt = axi_tr_cnt-1'b1; // 需要几次传几次
                                    end
                                    else begin
                                        axi_awlen_nxt = 8'hff; // 256次传满
                                    end
                                    axi_awvalid_nxt = 1'b1;
                                    if (axi_awvalid & axi_awready) begin
                                        axi_awvalid_nxt = 1'b0;
                                        burst_cnt_nxt   = (axi_tr_cnt <   = 256) ? axi_tr_cnt : 9'h100; // 重新计数
                                    end
                                end
                            end
                            else begin // 还没有发完
                                r_en_nxt = 1'b1;
                                if (r_en) begin
                                    r_en_nxt       = 0;
                                    axi_wdata_nxt  = data_to_axi;
                                    axi_wstrb_nxt  = (axi_tr_cnt == 1)?{AXI_STRB_WIDTH{1'b1}}>>(offset_lock<<2):{AXI_STRB_WIDTH{1'b1}};
                                    axi_wlast_nxt  = (burst_cnt == 1);
                                    axi_wvalid_nxt = 1'b1;
                                end
                                if (axi_wready & axi_wvalid) begin
                                    tr_status_nxt  = CONTINUE_TR;
                                    axi_wvalid_nxt = 0;
                                    burst_cnt_nxt  = burst_cnt_minus1;// 发送计数器-1
                                    axi_tr_cnt_nxt = axi_tr_cnt_minus1; // 总计数器-1
                                end
                            end
                        end
                        // IDLE_TR: begin
                            //     axi_wlast_nxt = 1'b1;
                        // end
                        default: status_nxt = WAITE_END;
                    endcase
                end
            end
            status[WAITE_END_IDX]: begin
                status_nxt = IDLE; // 缓冲一拍，让start_tx传到
            end
            default:;
        endcase
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            status      <= WAITE_END;
            tr_status   <= 0;
            axi_tr_cnt  <= 0;
            burst_cnt   <= 0;
            offset_lock <= 0;
            r_en        <= 0;
            // axi
            axi_awid    <= 0;
            axi_awaddr  <= 0;
            axi_awlen   <= 0;
            axi_awsize  <= 0;
            axi_awburst <= 0;
            axi_awlock  <= 0;
            axi_awprot  <= 0;
            axi_awcache <= 0;
            axi_awvalid <= 0;
            axi_wdata   <= 0;
            axi_wstrb   <= 0;
            axi_wlast   <= 0;
            axi_wvalid  <= 0;
        end
        else begin
            status        <= status_nxt;
            tr_status     <= tr_status_nxt;
            axi_tr_cnt    <= axi_tr_cnt_nxt;
            burst_cnt_nxt <= burst_cnt_nxt;
            offset_lock   <= offset_lock_nxt;
            r_en          <= r_en_nxt;
            axi_awid      <= axi_awid_nxt;
            axi_awaddr    <= axi_awaddr_nxt;
            axi_awlen     <= axi_awlen_nxt;
            axi_awsize    <= axi_awsize_nxt;
            axi_awburst   <= axi_awburst_nxt;
            axi_awlock    <= axi_awlock_nxt;
            axi_awcache   <= axi_awcache_nxt;
            axi_awprot    <= axi_awprot_nxt;
            axi_awvalid   <= axi_awvalid_nxt;
            axi_wdata     <= axi_wdata_nxt;
            axi_wstrb     <= axi_wstrb_nxt;
            axi_wlast     <= axi_wlast_nxt;
            axi_wvalid    <= axi_wvalid_nxt;
        end
    end
    
    localparam FIFO_DEPTH      = 16;
    localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);
    syn_fifo #(
        .DATA_WIDTH(TLP_DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(w_en),
        .w_data(data_to_fifo),
        .r_en(r_en),
        .r_data(data_to_axi),
        .is_empty(is_empty),
        .is_full(is_full),
        .room_avail(),
        .data_avail()
    );
    
endmodule
