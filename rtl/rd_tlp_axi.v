module rd_tlp_axi #(
    DOUBLE_WORD             =        32,
    HEADER_SIZE             =        4*DOUBLE_WORD,
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD,
    AXI_ID_WIDTH            =        8,
    AXI_DATA_WIDTH          =        TLP_DATA_WIDTH,
    AXI_ADDR_WIDTH          =        64,
    AXI_STRB_WIDTH          =        AXI_DATA_WIDTH/8,
    TLP_STRB_WIDTH          =        TLP_DATA_WIDTH/8
) (
    input       wire                                        clk,
    input       wire                                        rst_n,
    input       wire        [HEADER_SIZE-1:0]               req_tlp_hdr,
    input       wire                                        req_tlp_sop,
    input       wire                                        req_tlp_eop,
    input       wire                                        req_tlp_valid,
    output      reg                                         req_tlp_ready,
    output      reg         [HEADER_SIZE-1:0]               cpl_tlp_hdr,
    output      reg         [TLP_STRB_WIDTH-1:0]            cpl_tlp_strb,
    output      reg         [TLP_DATA_WIDTH-1:0]            cpl_tlp_data,
    output      reg                                         cpl_tlp_sop,
    output      reg                                         cpl_tlp_eop,
    output      reg                                         cpl_tlp_valid,
    input       wire                                        cpl_tlp_ready,
    input       reg         [AXI_ID_WIDTH-1:0]              axi_arid,
    output      reg         [AXI_ADDR_WIDTH-1:0]            axi_araddr,
    output      reg         [2:0]                           axi_arsize,
    output      reg         [7:0]                           axi_arlen,
    output      reg         [1:0]                           axi_arburst,
    output      reg         [2:0]                           axi_arprot,
    output      reg                                         axi_arlock,
    output      reg         [3:0]                           axi_arcache,
    output      reg                                         axi_arvalid,
    input       wire                                        axi_arready,
    input       wire        [AXI_DATA_WIDTH-1:0]            axi_rdata,
    input       wire        [AXI_STRB_WIDTH-1:0]            axi_rstrb,
    input       wire                                        axi_rlast,
    input       wire                                        axi_rvalid,
    output      reg                                         axi_rready,
    output      reg                                         tlp_error
);
    // request tlp
    reg                                                     req_tlp_ready_nxt;
    reg                     [HEADER_SIZE-1:0]               req_tlp_hdr_in,req_tlp_hdr_in_nxt;
    // complete tlp
    reg                     [HEADER_SIZE-1:0]               cpl_tlp_hdr_nxt;
    reg                     [TLP_DATA_WIDTH-1:0]            cpl_tlp_data_nxt;
    reg                     [TLP_STRB_WIDTH-1:0]            cpl_tlp_strb_nxt;
    reg                                                     cpl_tlp_sop_nxt;
    reg                                                     cpl_tlp_eop_nxt;
    reg                                                     cpl_tlp_valid_nxt;
    // axi ar
    reg                     [AXI_ID_WIDTH-1:0]              axi_arid_nxt;
    reg                     [AXI_ADDR_WIDTH-1:0]            axi_araddr_nxt;
    reg                     [2:0]                           axi_arsize_nxt;
    reg                     [7:0]                           axi_arlen_nxt;
    reg                     [1:0]                           axi_arburst_nxt;
    reg                     [2:0]                           axi_arprot_nxt;
    reg                     [3:0]                           axi_arcache_nxt;
    reg                                                     axi_arlock_nxt;
    reg                                                     axi_arvalid_nxt;
    // axi r
    reg                                                     axi_rready_nxt;
    // error
    reg                                                     tlp_error_nxt;
    // globle control
    reg                                                     req_busy,req_busy_nxt;    // 读请求处理标识
    reg                                                     start_ar,start_ar_nxt;    // 开始产生AR信号
    reg                                                     busy_r,busy_r_nxt;    // AXI正在接收
    reg                                                     cpl_first,cpl_first_nxt;
    localparam RCB              = 128; // read complete bounderay, 128byte
    localparam AXI_DW_WIDTH     = AXI_DATA_WIDTH/DOUBLE_WORD; // 256/32     = 8
    localparam AXI_DW_WIDTH_LOG = $clog2(AXI_DW_WIDTH);
    /*
     * request TLP input
     */
    
    always @* begin
        req_tlp_ready_nxt  = req_tlp_ready;
        req_busy_nxt       = req_busy;
        start_ar_nxt       = start_ar;
        req_tlp_hdr_in_nxt = req_tlp_hdr_in;
        // 目前没有正在处理的request
        if (!req_busy) begin
            req_tlp_ready_nxt = 1'b1;
        end
        // 接收到req tlp
        if (req_tlp_valid & req_tlp_ready & req_tlp_sop) begin
            req_tlp_ready_nxt  = 1'b0;
            req_busy_nxt       = 1'b1;
            start_ar_nxt       = 1'b1;
            req_tlp_hdr_in_nxt = req_tlp_hdr;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            req_tlp_ready  <= 0;
            req_busy       <= 0;
            req_tlp_hdr_in <= 0;
            start_ar       <= 1'b0;
        end
        else begin
            req_tlp_ready  <= req_tlp_ready_nxt;
            req_busy       <= req_busy_nxt;
            start_ar       <= start_ar_nxt;
            req_tlp_hdr_in <= req_tlp_hdr_in_nxt;
        end
    end
    /*
     * axi ar output
     */
    // tlp header fields
    wire                    [2:0]                           req_fmt;
    wire                    [4:0]                           req_type;
    wire                    [2:0]                           req_tc;
    wire                    [2:0]                           req_attr;
    wire                                                    req_ln;
    wire                                                    req_th;
    wire                                                    req_td;
    wire                                                    req_ep;
    wire                    [1:0]                           req_at;
    wire                    [10:0]                          req_length;
    wire                    [15:0]                          req_req_id;
    wire                    [9:0]                           req_tag;
    wire                    [3:0]                           req_first_be;
    wire                    [3:0]                           req_last_be;
    wire                    [63:0]                          req_addr;
    wire                    [1:0]                           req_ph;
    // extract fields
    assign req_fmt      = req_tlp_hdr_in[127:125];
    assign req_type     = req_tlp_hdr_in[124:120];
    assign req_tc       = req_tlp_hdr_in[118:116];
    assign req_attr     = {req_tlp_hdr_in[114],req_tlp_hdr_in[109:108]};
    assign req_ln       = req_tlp_hdr_in[113];
    assign req_th       = req_tlp_hdr_in[112];
    assign req_td       = req_tlp_hdr_in[111];
    assign req_ep       = req_tlp_hdr_in[110];
    assign req_at       = req_tlp_hdr_in[107:106];
    assign req_length   = {req_tlp_hdr_in[105:96] == 10'b0, req_tlp_hdr_in[105:96]} - 1'b1; // 0-1023 DW
    assign req_req_id   = req_tlp_hdr_in[95:80];
    assign req_tag      = {req_tlp_hdr_in[119], req_tlp_hdr_in[115], req_tlp_hdr_in[79:72]};
    assign req_last_be  = req_tlp_hdr_in[71:68];
    assign req_first_be = req_tlp_hdr_in[67:64];
    assign req_addr     = req_fmt[0] ? {req_tlp_hdr_in[63:2], 2'b0} : {32'b0, req_tlp_hdr_in[31:2], 2'b0};
    assign req_ph       = req_fmt[0] ? req_tlp_hdr_in[1:0] : req_tlp_hdr_in[33:32];
    
    reg                     [2:0]                           single_dword_len;
    reg                     [1:0]                           last_be_offset;
    reg                     [1:0]                           first_be_offset;
    
    localparam AXI_REQ_BURST_LEN = 1024*DOUBLE_WORD/AXI_DATA_WIDTH;
    localparam BURST_CNT_LOG     = $clog2(AXI_REQ_BURST_LEN)+1;
    localparam AXI_SIZE          = $clog2(AXI_DATA_WIDTH/8);
    reg                     [BURST_CNT_LOG-1:0]             globle_tr_cnt,globle_tr_cnt_nxt;    // 全局计数，传输所有数据需要几次transfer
    reg                     [8:0]                           burst_cnt,burst_cnt_nxt;    // burst trnansfer 计数，记录一次burst进行了几次发送
    reg                                                     axi_first,axi_first_nxt;
    reg                     [CPL_CNT_LOG:0]                 rcb_cnt,rcb_cnt_nxt;
    // generate axi ar
    always @* begin
        // 单DW传输byte count
        casez (req_first_be)
            4'b1zz1: single_dword_len = 3'h4;
            4'b01z1: single_dword_len = 3'h3;
            4'b1z10: single_dword_len = 3'h3;
            4'b0011: single_dword_len = 3'h2;
            4'b0110: single_dword_len = 3'h2;
            4'b1100: single_dword_len = 3'h2;
            4'b0001: single_dword_len = 3'h1;
            4'b0010: single_dword_len = 3'h1;
            4'b0100: single_dword_len = 3'h1;
            4'b1000: single_dword_len = 3'h1;
            4'b0000: single_dword_len = 3'h1;
            default: single_dword_len = 3'h1;
        endcase
        // last_be_offset
        casez (req_last_be)
            4'b0000: last_be_offset = 2'b00;
            4'b0001: last_be_offset = 2'b11;
            4'b001z: last_be_offset = 2'b10;
            4'b01zz: last_be_offset = 2'b01;
            4'b1zzz: last_be_offset = 2'b00;
            default: last_be_offset = 2'b00;
        endcase
        // first_be_offset
        casez (req_first_be)
            4'b0000: first_be_offset = 2'b00;
            4'bzzz1: first_be_offset = 2'b00;
            4'bzz10: first_be_offset = 2'b01;
            4'bz100: first_be_offset = 2'b10;
            4'b1000: first_be_offset = 2'b11;
            default: first_be_offset = 2'b00;
        endcase
        // default value
        axi_arid_nxt    = {AXI_ID_WIDTH{1'b0}};
        axi_araddr_nxt  = axi_araddr;
        axi_arlen_nxt   = axi_arlen;
        axi_arsize_nxt  = 3'h5;
        axi_arburst_nxt = 2'b1;
        axi_arprot_nxt  = 3'b010; // no privilege; unsafe; data
        axi_arlock_nxt  = 1'b0;
        axi_arcache_nxt = 4'b0011;
        axi_arvalid_nxt = axi_arvalid;
        
        burst_cnt_nxt     = burst_cnt;
        globle_tr_cnt_nxt = globle_tr_cnt;
        busy_r_nxt        = busy_r;
        axi_first_nxt     = axi_first;
        rcb_cnt_nxt       = rcb_cnt;
        // 开始产生ar控制信号
        if (req_busy & start_ar) begin
            start_ar_nxt = 1'b0;
            // 计数器
            globle_tr_cnt_nxt = (req_length >> AXI_DW_WIDTH_LOG) + 1'b1; // 全局传输数据次数
            // axi
            axi_arvalid_nxt = 1'b1;
            axi_araddr_nxt  = {req_addr[63:2], first_be_offset}; // TODO
            if (globle_tr_cnt_nxt <= 256) begin
                axi_arlen_nxt = (req_length >> AXI_DW_WIDTH_LOG);
                burst_cnt_nxt = globle_tr_cnt_nxt;
            end
            else begin
                axi_arlen_nxt = 8'hff;
                burst_cnt_nxt = 9'b100;
            end
            axi_first_nxt = 1'b1;
            cpl_first_nxt = 1'b1;
            rcb_cnt_nxt = ~(req_addr[7:AXI_SIZE+1])+1'b1 // 对齐到128字节边界需要的第一次传输的次数
        end
        // 一次burst结束更新ar控制信号
        if (busy_r & axi_rlast) begin
            if (|globle_tr_cnt_nxt) begin // 还有数据没读
                if (globle_tr_cnt <= 256) begin
                    axi_arlen_nxt = globle_tr_cnt - 1'b1;
                end
                else begin
                    axi_arlen_nxt = 8'hff;
                end
                axi_araddr_nxt  = axi_araddr[63:AXI_SIZE] + 256*AXI_DATA_WIDTH/8;
                axi_arvalid_nxt = 1'b1;
            end
            else begin // 该tlp请求的数据全部读取完毕
                busy_r_nxt = 1'b0; // 结束读取
            end
        end
        // 消除arvalid
        if (axi_arvalid & axi_arready) begin
            axi_arvalid_nxt = 1'b0;
            busy_r_nxt      = 1'b1;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_arid      <= 0;
            axi_araddr    <= 0;
            axi_arlen     <= 0;
            axi_arburst   <= 0;
            axi_arprot    <= 0;
            axi_arlock    <= 0;
            axi_arcache   <= 0;
            axi_arsize    <= 0;
            axi_arvalid   <= 0;
            burst_cnt     <= 0;
            globle_tr_cnt <= 0;
            busy_r        <= 0;
            axi_first     <= 0;
            rcb_cnt       <= 0;
        end
        else begin
            axi_arid      <= axi_arid_nxt;
            axi_araddr    <= axi_araddr_nxt;
            axi_arlen     <= axi_arlen_nxt;
            axi_arburst   <= axi_arburst_nxt;
            axi_arprot    <= axi_arprot_nxt;
            axi_arlock    <= axi_arlock_nxt;
            axi_arcache   <= axi_arcache_nxt;
            axi_arsize    <= axi_arsize_nxt;
            axi_arvalid   <= axi_arvalid_nxt;
            burst_cnt     <= burst_cnt_nxt;
            globle_tr_cnt <= globle_tr_cnt_nxt;
            busy_r        <= busy_r_nxt;
            axi_first     <= axi_first_nxt;
            rcb_cnt       <= rcb_cnt_nxt;
        end
    end
    /*
     * axi read data input
     */
    reg                     [AXI_DATA_WIDTH-1:0]            axi_rdata_in,axi_rdata_in_nxt;
    reg                     [AXI_STRB_WIDTH-1:0]            axi_rstrb_in,axi_rstrb_in_nxt;
    reg                                                     axi_rvalid_in,axi_rvalid_in_nxt;
    always @* begin
        axi_rvalid_in_nxt = 0;
        axi_rdata_in_nxt  = axi_rdata_in;
        axi_rstrb_in_nxt  = axi_rstrb_in;
        axi_rready_nxt    = busy_r_nxt & ((cpl_tlp_ready & cpl_tlp_valid) | ~cpl_tlp_valid);
        if (axi_rvalid & axi_rready) begin
            axi_first_nxt     = 1'b0;
            axi_rvalid_in_nxt = 1'b1;
            axi_rready_nxt    = 1'b0;
            axi_rdata_in_nxt  = axi_rdata;
            axi_rstrb_in_nxt  = axi_rstrb;
            globle_tr_cnt_nxt = globle_tr_cnt - 1'b1;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_rvalid_in <= 0;
            axi_rdata_in  <= 0;
            axi_rstrb_in  <= 0;
            axi_rready    <= 0;
        end
        else begin
            axi_rvalid_in <= axi_rvalid_in_nxt;
            axi_rdata_in  <= axi_rdata_in_nxt;
            axi_rstrb_in  <= axi_rstrb_in_nxt;
            axi_rready    <= axi_rready_nxt;
        end
    end
    
    /*
     * complete TLP with data output
     * 两部分功能，一是AXI数据需要通过strb辨识有效数据部分，二是cpl payload部分需要基于RCB分割多个TLP，通过valid_in判断数据是否有效
     */
    reg                     [2:0]                           cpl_fmt;
    reg                     [4:0]                           cpl_type;
    reg                     [2:0]                           cpl_tc;
    reg                     [9:0]                           cpl_tag;
    reg                     [2:0]                           cpl_attr;
    reg                                                     cpl_ln;
    reg                                                     cpl_th;
    reg                                                     cpl_ep;
    reg                                                     cpl_td;
    reg                     [1:0]                           cpl_at;
    reg                     [9:0]                           cpl_length;
    reg                     [15:0]                          cpl_com_id;
    reg                     [2:0]                           cpl_com_status;
    reg                                                     cpl_bcm;
    reg                     [11:0]                          cpl_byte_cnt;
    reg                     [15:0]                          cpl_req_id;
    reg                     [6:0]                           cpl_lower_addr;
    
    wire                    [2*AXI_DATA_WIDTH-1:0]          axi_shift;
    assign axi_shift           = {axi_rdata, axi_rdata_in}<<(~axi_araddr[AXI_SIZE-1:0]);
    localparam RCB_CNT_DEFAULT = RCB/(AXI_DATA_WIDTH>>3);
    localparam CPL_CNT_LOG     = $clog2(RCB_CNT_DEFAULT);
    
    always @* begin
        // default values
        cpl_fmt  = (|req_length) ? 3'b010 : 3'b000; // 根据请求的length确定cpl是否包含数据
        cpl_type = 5'b01010;
        cpl_tc   = 3'b0;
        cpl_ln   = 1'b0;
        cpl_th   = 1'b0;
        cpl_ep   = 1'b0;
        cpl_td   = 1'b0;
        cpl_at   = 2'b0;
        // cpl header
        cpl_tlp_hdr_nxt[127:125] = cpl_fmt;
        cpl_tlp_hdr_nxt[124:120] = cpl_type;
        cpl_tlp_hdr_nxt[119]     = cpl_tag[9]; // TODO
        cpl_tlp_hdr_nxt[118:116] = cpl_tc;
        cpl_tlp_hdr_nxt[115]     = cpl_tag[8]; // TODO
        cpl_tlp_hdr_nxt[114]     = cpl_attr[2]; // TODO
        cpl_tlp_hdr_nxt[113]     = cpl_ln;
        cpl_tlp_hdr_nxt[112]     = cpl_th;
        cpl_tlp_hdr_nxt[111]     = cpl_td;
        cpl_tlp_hdr_nxt[110]     = cpl_ep;
        cpl_tlp_hdr_nxt[109:108] = cpl_attr[1:0]; // TODO
        cpl_tlp_hdr_nxt[107:106] = cpl_at;
        cpl_tlp_hdr_nxt[105:96]  = cpl_length; // TODO
        cpl_tlp_hdr_nxt[95:80]   = cpl_com_id; // TODO
        cpl_tlp_hdr_nxt[79:77]   = cpl_com_status; // TODO
        cpl_tlp_hdr_nxt[76]      = cpl_bcm;
        cpl_tlp_hdr_nxt[75:64]   = cpl_byte_cnt; // TODO
        cpl_tlp_hdr_nxt[63:48]   = cpl_req_id; // TODO
        cpl_tlp_hdr_nxt[47:40]   = cpl_tag; // TODO
        cpl_tlp_hdr_nxt[39]      = 1'b0;
        cpl_tlp_hdr_nxt[38:32]   = cpl_lower_addr; // TODO
        cpl_tlp_hdr_nxt[31:0]    = 32'b0;
        
        cpl_tlp_data_nxt  = cpl_tlp_data;
        cpl_tlp_strb_nxt  = cpl_tlp_strb;
        cpl_tlp_valid_nxt = cpl_tlp_valid;
        cpl_tlp_sop_nxt   = cpl_tlp_sop;
        cpl_tlp_eop_nxt   = cpl_tlp_eop;
        
        cpl_first_nxt = cpl_first;
        
        if (cpl_tlp_eop) begin
            cpl_first_nxt = 1'b0;
            rcb_cnt_nxt   = RCB_CNT_DEFAULT;
        end
        // clear
        if (cpl_tlp_valid & cpl_tlp_ready) begin
            cpl_tlp_valid_nxt = 1'b0;
            cpl_tlp_sop_nxt   = 1'b0;
            cpl_tlp_eop_nxt   = 1'b0;
            rcb_cnt_nxt       = cpl_first ? (rcb_cnt - 1'b1) : rcb_cnt;
        end
        // data sop
        if (axi_rready & axi_rvalid & ~axi_first) begin
            cpl_tlp_valid_nxt = 1'b1;
            if (cpl_first) begin
                cpl_tlp_data_nxt = axi_shift[2*AXI_DATA_WIDTH-1:AXI_DATA_WIDTH];
                if (rcb_cnt == (~(req_addr[7:AXI_SIZE+1])+1'b1)) begin
                    cpl_tlp_sop_nxt = 1'b1;
                end
            end
            else begin
                cpl_tlp_data_nxt = axi_rdata_in;
                if (rcb_cnt == RCB_CNT_DEFAULT) begin
                    cpl_tlp_sop_nxt = 1'b1;
                end
            end
        end
        // header update

        // normal eop
        if (rcb_cnt == 1'b1) begin
            if (axi_rvalid & axi_rready & ~axi_first) begin
                cpl_tlp_eop_nxt = 1'b1;
            end
        end
        // last eop
        if (globle_tr_cnt == 0) begin // 最后一个数据
            
        end
        // cpl strb
        if (cpl_first & cpl_tlp_eop_nxt) begin // first cpl 最后一个数据对齐
            cpl_tlp_strb_nxt = {TLP_STRB_WIDTH{1'b1}}>>(~axi_araddr[AXI_SIZE-1:0]+1'b1);
        end
        else begin
            cpl_tlp_strb_nxt = axi_rstrb_in;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            cpl_tlp_hdr   <= 0;
            cpl_tlp_data  <= 0;
            cpl_tlp_strb  <= 0;
            cpl_tlp_sop   <= 0;
            cpl_tlp_eop   <= 0;
            cpl_tlp_valid <= 0;
            cpl_first     <= 0;
        end
        else begin
            cpl_tlp_hdr   <= cpl_tlp_hdr_nxt;
            cpl_tlp_data  <= cpl_tlp_data_nxt;
            cpl_tlp_strb  <= cpl_tlp_strb_nxt;
            cpl_tlp_valid <= cpl_tlp_valid_nxt;
            cpl_tlp_sop   <= cpl_tlp_sop_nxt;
            cpl_tlp_eop   <= cpl_tlp_eop_nxt;
            cpl_first     <= cpl_first_nxt;
        end
    end
    
endmodule
