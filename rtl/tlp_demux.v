/*
 * @Author=Milo
 * @Function= pcie事务包读写解复用器，将读请求tlp与写请求tlp区分分别输出
 */

module tlp_demux #(
    PORTS                   =        2,                                  // 解复用输出端口，在此解复用器用作读写复用，故为2
    DOUBLE_WORD             =        32,                                 // 双字，32位
    HEADER_SIZE             =        4*DOUBLE_WORD,                      // Header4个双字，取决于host内存空间是否大于4GB
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD                       // 数据荷载8个双字
) (
    input       wire                                        clk,
    input       wire                                        rst_n,
    input       wire        [TLP_DATA_WIDTH-1:0]            in_data,     // 输入TLP包数据
    input       wire        [HEADER_SIZE-1:0]               in_hdr,      // 输入TLP包头
    input       wire                                        in_sop,
    input       wire                                        in_eop,
    input       wire                                        in_valid,
    output      reg                                         in_ready,
    output      reg         [TLP_DATA_WIDTH-1:0]            r_out_data,  // 输出读请求TLP包
    output      reg         [HEADER_SIZE-1:0]               r_out_hdr,
    output      reg                                         r_out_sop,
    output      reg                                         r_out_eop,
    output      reg                                         r_out_valid,
    input                                                   r_out_ready,
    output      reg         [TLP_DATA_WIDTH-1:0]            w_out_data,  // 输出写请求TLP包
    output      reg         [HEADER_SIZE-1:0]               w_out_hdr,
    output      reg                                         w_out_sop,
    output      reg                                         w_out_eop,
    output      reg                                         w_out_valid,
    input       wire                                        w_out_ready,
    input       wire                                        enable
);
    reg                                                     in_ready_nxt;
    // assign in_ready = in_ready_nxt;
    /*
     * 输出读请求TLP
     */
    reg                     [TLP_DATA_WIDTH-1:0]            r_out_data_nxt;
    reg                     [HEADER_SIZE-1:0]               r_out_hdr_nxt;
    reg                                                     r_out_sop_nxt;
    reg                                                     r_out_eop_nxt;
    reg                                                     r_out_valid_nxt;
    /*
     * 输出写请求TLP
     */
    reg                     [TLP_DATA_WIDTH-1:0]            w_out_data_nxt;
    reg                     [HEADER_SIZE-1:0]               w_out_hdr_nxt;
    reg                                                     w_out_sop_nxt;
    reg                                                     w_out_eop_nxt;
    reg                                                     w_out_valid_nxt;
    /*
     * 输入TLP筛选，主要控制valid信号，筛除不合格的TLP
     */
    wire                    [TLP_DATA_WIDTH-1:0]            in_data_wire;
    wire                    [HEADER_SIZE-1:0]               in_hdr_wire;
    wire                                                    in_sop_wire;
    wire                                                    in_eop_wire;
    wire                                                    in_valid_wire;
    // wire                                                     in_ready_wire;
    /*
     * 内部TLP缓存，
     */
    reg                     [TLP_DATA_WIDTH-1:0]            tmp_data,tmp_data_nxt;
    reg                     [HEADER_SIZE-1:0]               tmp_hdr,tmp_hdr_nxt;
    reg                                                     tmp_sop,tmp_sop_nxt;
    reg                                                     tmp_eop,tmp_eop_nxt;
    reg                                                     tmp_valid,tmp_valid_nxt;
    // reg                                                     tmp_ready;
    
    /*
     * 输入TLP包筛选控制，提取读写标识
     */
    // reg                                                     drop,drop_nxt;
    // reg                                                     frame,frame_nxt;
    wire                                                    wr_rd;    // TLP为写类型：1；TLP为读类型：0
    wire                                                    tmp_wr_rd;
    wire                                                    islegal;
    localparam RD_FMT_TYPE = 8'b001_00000;
    localparam WR_FMT_TYPE = 8'b011_00000;
    // 判断输入TLP是否为存储区读写TLP
    assign islegal   = (in_hdr[(HEADER_SIZE-1)-:8] == RD_FMT_TYPE) || (in_hdr[(HEADER_SIZE-1)-:8] == WR_FMT_TYPE);
    assign wr_rd     = in_hdr[HEADER_SIZE-2];
    assign tmp_wr_rd = tmp_hdr[HEADER_SIZE-2];
    
    assign in_data_wire  = in_data;
    assign in_hdr_wire   = in_hdr;
    assign in_sop_wire   = in_sop;
    assign in_eop_wire   = in_eop;
    assign in_valid_wire = islegal & in_valid;
    /*
     * 数据流状态机控制
     */
    // flags
    // reg                     [2:0]                           status,status_nxt;
    reg                                                     in_to_w;
    reg                                                     in_to_r;
    reg                                                     in_to_tmp;
    reg                                                     tmp_to_w;
    reg                                                     tmp_to_r;
    // reg                                                     shut_w,shut_r;
    // 产生ready信号，控制状态转移
    always @* begin
        // status_nxt   = status;
        in_ready_nxt = in_ready;
        // 5种数据流向
        in_to_w   = 0;
        in_to_r   = 0;
        in_to_tmp = 0;
        tmp_to_w  = 0;
        tmp_to_r  = 0;
        // shut_w = 0;
        // shut_r = 0;
        // 三种使能信号
        tmp_valid_nxt   = tmp_valid;
        r_out_valid_nxt = r_out_valid;
        w_out_valid_nxt = w_out_valid;
        if (!tmp_valid) begin
            in_ready_nxt = 1'b1;
        end
        else begin
            in_ready_nxt = (wr_rd & !tmp_wr_rd & !w_out_valid) | (!wr_rd & tmp_wr_rd & !r_out_valid);
        end
        
        if (in_ready & in_valid_wire) begin
            in_ready_nxt = 0;
            in_to_w      = wr_rd & !tmp_valid & !w_out_valid;
            in_to_r      = (!wr_rd) & !tmp_valid & !r_out_valid;
            in_to_tmp    = !tmp_valid & (w_out_valid & r_out_valid);
        end
        
        tmp_to_w = tmp_wr_rd & tmp_valid & !w_out_valid;
        tmp_to_r = !tmp_wr_rd & tmp_valid & !r_out_valid;
        
        w_out_valid_nxt = in_to_w | tmp_to_w;
        r_out_valid_nxt = in_to_r | tmp_to_r;
        tmp_valid_nxt   = in_to_tmp;
        
        if (w_out_valid & w_out_ready) begin
            w_out_valid_nxt = 0;
            w_out_sop_nxt = 0;
            w_out_eop_nxt = 0;
        end
        
        if (r_out_ready & r_out_valid) begin
            r_out_valid_nxt = 0;
            r_out_sop_nxt = 0;
            r_out_eop_nxt = 0;
        end
        
        if (tmp_to_w | tmp_to_r) begin
            tmp_valid_nxt = 0;
        end
    end
    /*
     * 数据传递
     */
    always @* begin
        tmp_data_nxt     = tmp_data;
        tmp_hdr_nxt      = tmp_hdr;
        tmp_sop_nxt      = tmp_sop;
        tmp_eop_nxt      = tmp_eop;
        // tmp_valid_nxt = tmp_valid;
        
        r_out_data_nxt     = r_out_data;
        r_out_hdr_nxt      = r_out_hdr;
        r_out_sop_nxt      = r_out_sop;
        r_out_eop_nxt      = r_out_eop;
        // r_out_valid_nxt = r_out_valid;
        
        w_out_data_nxt     = w_out_data;
        w_out_hdr_nxt      = w_out_hdr;
        w_out_sop_nxt      = w_out_sop;
        w_out_eop_nxt      = w_out_eop;
        // w_out_valid_nxt = w_out_valid;
        // 输入到缓存
        if (in_to_tmp) begin
            tmp_data_nxt     = in_data_wire;
            tmp_hdr_nxt      = in_hdr_wire;
            tmp_sop_nxt      = in_sop_wire;
            tmp_eop_nxt      = in_eop_wire;
            // tmp_valid_nxt = in_valid_wire;
        end
        // 输入到读输出
        if (in_to_r) begin
            r_out_data_nxt     = in_data_wire;
            r_out_hdr_nxt      = in_hdr_wire;
            r_out_sop_nxt      = in_sop_wire;
            r_out_eop_nxt      = in_eop_wire;
            // r_out_valid_nxt = in_valid_wire;
        end
        // 输入到写输出
        if (in_to_w) begin
            w_out_data_nxt     = in_data_wire;
            w_out_hdr_nxt      = in_hdr_wire;
            w_out_sop_nxt      = in_sop_wire;
            w_out_eop_nxt      = in_eop_wire;
            // w_out_valid_nxt = in_valid_wire;
        end
        // 缓存到读输出
        if (tmp_to_r) begin
            r_out_data_nxt     = tmp_data;
            r_out_hdr_nxt      = tmp_hdr;
            r_out_sop_nxt      = tmp_sop;
            r_out_eop_nxt      = tmp_eop;
            // r_out_valid_nxt = tmp_valid;
        end
        // 缓存到写输出
        if (tmp_to_w) begin
            w_out_data_nxt     = tmp_data;
            w_out_hdr_nxt      = tmp_hdr;
            w_out_sop_nxt      = tmp_sop;
            w_out_eop_nxt      = tmp_eop;
            // w_out_valid_nxt = tmp_valid;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            // status   <= 0;
            in_ready <= 0;
            
            tmp_data  <= 0;
            tmp_hdr   <= 0;
            tmp_sop   <= 0;
            tmp_eop   <= 0;
            tmp_valid <= 0;
            
            r_out_data  <= 0;
            r_out_hdr   <= 0;
            r_out_sop   <= 0;
            r_out_eop   <= 0;
            r_out_valid <= 0;
            
            w_out_data  <= 0;
            w_out_hdr   <= 0;
            w_out_sop   <= 0;
            w_out_eop   <= 0;
            w_out_valid <= 0;
        end
        else begin
            // status   <= status_nxt;
            in_ready <= in_ready_nxt;
            
            tmp_data  <= tmp_data_nxt;
            tmp_hdr   <= tmp_hdr_nxt;
            tmp_sop   <= tmp_sop_nxt;
            tmp_eop   <= tmp_eop_nxt;
            tmp_valid <= tmp_valid_nxt;
            
            r_out_data  <= r_out_data_nxt;
            r_out_hdr   <= r_out_hdr_nxt;
            r_out_sop   <= r_out_sop_nxt;
            r_out_eop   <= r_out_eop_nxt;
            r_out_valid <= r_out_valid_nxt;
            
            w_out_data  <= w_out_data_nxt;
            w_out_hdr   <= w_out_hdr_nxt;
            w_out_sop   <= w_out_sop_nxt;
            w_out_eop   <= w_out_eop_nxt;
            w_out_valid <= w_out_valid_nxt;
        end
    end
    
endmodule
