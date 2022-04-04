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
    output                                                  in_ready,
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
    assign in_ready = in_ready_nxt;
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
    // 状态定义
    localparam ALL_0   = 8'b0000_0001; // tmp:0; w_out:0; r_out:0
    localparam TMP_W_0 = 8'b0000_0010; //     0        0        1
    localparam TMP_R_0 = 8'b0000_0100; //     0        1        0
    localparam TMP_0   = 8'b0000_1000; //     0        1        1
    localparam W_R_0   = 8'b0001_0000; //     1        0        0
    localparam W_0     = 8'b0010_0000; //     1        0        1
    localparam R_0     = 8'b0100_0000; //     1        1        0
    localparam ALL_1   = 8'b1000_0000; //     1        1        1
    
    localparam ALL_0_BIT   = 0;
    localparam TMP_W_0_BIT = 1;
    localparam TMP_R_0_BIT = 2;
    localparam TMP_0_BIT   = 3;
    localparam W_R_0_BIT   = 4;
    localparam W_0_BIT     = 5;
    localparam R_0_BIT     = 6;
    localparam ALL_1_BIT   = 7;
    // flags
    reg                     [7:0]                           status,status_nxt;
    reg                                                     in_to_w;
    reg                                                     in_to_r;
    reg                                                     in_to_tmp;
    reg                                                     tmp_to_w;
    reg                                                     tmp_to_r;
    reg                                                     shut_w,shut_r;
    // 产生ready信号，控制状态转移
    always @* begin
        status_nxt   = status;
        in_ready_nxt = in_ready;
        // 5种数据流向
        in_to_w   = 0;
        in_to_r   = 0;
        in_to_tmp = 0;
        tmp_to_w  = 0;
        tmp_to_r  = 0;
        shut_w    = 0;
        shut_r    = 0;
        case(1'b1)
            status[ALL_0_BIT]: begin
                in_ready_nxt = 1'b1;
                // shut_r    = 1;
                // shut_w    = 1;
                if (in_valid_wire & in_ready) begin // 输入数据有效
                    in_to_w    = wr_rd; // 写请求
                    in_to_r    = !wr_rd; // 读请求
                    status_nxt = (wr_rd) ? TMP_R_0 : TMP_W_0;
                    // shut_w  = wr_rd ? 0:1;
                    // shut_r  = wr_rd ? 1:0;
                end
            end
            status[TMP_W_0_BIT]: begin
                in_ready_nxt = 1'b1;
                // shut_w    = 1;
                if (in_valid_wire & in_ready) begin // 输入数据有效
                    // shut_w = wr_rd ? 0:1;
                    if (r_out_ready) begin
                        in_to_r    = !wr_rd;
                        in_to_w    = wr_rd;
                        status_nxt = wr_rd ? TMP_R_0 : TMP_W_0;
                        // shut_r  = 1;
                    end
                    else begin
                        in_to_tmp  = !wr_rd;
                        in_to_w    = wr_rd;
                        status_nxt = wr_rd ? TMP_0 : W_0;
                    end
                end
                else begin
                    if (r_out_ready) begin
                        shut_r     = 1'b1; // 将R数据置为无效
                        status_nxt = ALL_0;
                        
                    end
                end
            end
            status[TMP_R_0_BIT]: begin
                in_ready_nxt = 1'b1;
                // shut_r    = 1;
                if (in_valid_wire & in_ready) begin // 输入数据有效
                    // shut_r = wr_rd?1:0;
                    if (w_out_ready) begin
                        in_to_r    = !wr_rd;
                        in_to_w    = wr_rd;
                        status_nxt = wr_rd ? TMP_R_0 : TMP_W_0;
                        // shut_w  = 1;
                    end
                    else begin
                        in_to_tmp  = wr_rd;
                        in_to_r    = !wr_rd;
                        status_nxt = wr_rd ? R_0 : TMP_0;
                    end
                end
                else begin
                    if (r_out_ready) begin
                        status_nxt = ALL_0;
                        shut_r     = 1;
                    end
                end
            end
            status[TMP_0_BIT]: begin
                in_ready_nxt = 1'b1;
                if (in_valid_wire & in_ready) begin
                    if (w_out_ready | r_out_ready) begin
                        if (w_out_ready & r_out_ready) begin
                            in_to_w    = wr_rd; // 写请求
                            in_to_r    = !wr_rd; // 读请求
                            status_nxt = (wr_rd) ? TMP_R_0 : TMP_W_0;
                            shut_r     = 1;
                            shut_w     = 1;
                        end
                        else if (w_out_ready) begin
                            in_to_tmp  = !wr_rd;
                            in_to_w    = wr_rd;
                            status_nxt = wr_rd ? TMP_0 : W_0;
                            shut_w     = 1;
                        end
                        else begin
                            in_to_tmp  = wr_rd;
                            in_to_r    = !wr_rd;
                            status_nxt = wr_rd ? R_0 : TMP_0;
                            shut_r     = 1;
                        end
                    end
                    else begin
                        in_to_tmp  = 1'b1;
                        status_nxt = ALL_1;
                    end
                end
                else begin
                    if (w_out_ready | r_out_ready) begin
                        if (w_out_ready & r_out_ready) begin
                            status_nxt = ALL_0;
                            shut_r     = 1;
                            shut_w     = 1;
                        end
                        else if (w_out_ready) begin
                            status_nxt = TMP_W_0;
                            shut_w     = 1;
                        end
                        else begin
                            status_nxt = TMP_R_0;
                            shut_r     = 1;
                        end
                    end
                end
            end
            status[W_R_0_BIT]: begin
                in_ready_nxt = 1'b1;
                // shut_r    = tmp_wr_rd ? 1 : 0;
                // shut_w    = tmp_wr_rd ? 0 : 1;
                tmp_to_r     = !tmp_wr_rd;
                tmp_to_w     = tmp_wr_rd;
                if (in_valid_wire & in_ready) begin
                    in_to_tmp  = 1'b1;
                    status_nxt = tmp_wr_rd ? R_0 : W_0;
                end
                else begin
                    status_nxt = tmp_wr_rd ? TMP_R_0 : TMP_W_0;
                end
            end
            status[W_0_BIT]: begin
                in_ready_nxt = 1'b0;
                // shut_w    = 1;
                if (r_out_ready) begin
                    // shut_r = 1;
                    tmp_to_r  = !tmp_wr_rd;
                end
                else begin
                    tmp_to_w  = tmp_wr_rd;
                    // shut_w = 0;
                end
                status_nxt = tmp_wr_rd ? (r_out_ready ? TMP_R_0 : TMP_0) : (r_out_ready ? TMP_W_0 : W_0);
            end
            status[R_0_BIT]: begin
                in_ready_nxt = 1'b0;
                // shut_r    = 1;
                if (w_out_ready) begin
                    tmp_to_w  = tmp_wr_rd;
                    // shut_w = 1;
                end
                else begin
                    tmp_to_r  = !tmp_wr_rd;
                    // shut_r = 0;
                end
                status_nxt = tmp_wr_rd ? (w_out_ready ? TMP_R_0 : R_0) : (w_out_ready ? TMP_W_0 : TMP_0);
            end
            status[ALL_1_BIT]: begin
                in_ready_nxt = 1'b0;
                if (r_out_ready | w_out_ready) begin
                    if (r_out_ready & w_out_ready) begin
                        status_nxt = W_R_0;
                        shut_r     = 1;
                        shut_w     = 1;
                    end
                    else if (w_out_ready) begin
                        status_nxt = W_0;
                        shut_w     = 1;
                    end
                    else begin
                        status_nxt = R_0;
                        shut_r     = 1;
                    end
                end
            end
            default:in_ready_nxt = 1'b0;
        endcase
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            status   <= 8'b1;
            // in_ready <= 1'b0;
        end
        else begin
            status   <= status_nxt;
            // in_ready <= in_ready_nxt;
        end
    end
    /*
     * 数据传递
     */
    always @* begin
        tmp_data_nxt  = tmp_data;
        tmp_hdr_nxt   = tmp_hdr;
        tmp_sop_nxt   = tmp_sop;
        tmp_eop_nxt   = tmp_eop;
        tmp_valid_nxt = tmp_valid;
        
        r_out_data_nxt  = r_out_data;
        r_out_hdr_nxt   = r_out_hdr;
        r_out_sop_nxt   = r_out_sop;
        r_out_eop_nxt   = r_out_eop;
        r_out_valid_nxt = r_out_valid;
        
        w_out_data_nxt  = w_out_data;
        w_out_hdr_nxt   = w_out_hdr;
        w_out_sop_nxt   = w_out_sop;
        w_out_eop_nxt   = w_out_eop;
        w_out_valid_nxt = w_out_valid;
        // 输入到缓存
        if (in_to_tmp) begin
            tmp_data_nxt  = in_data_wire;
            tmp_hdr_nxt   = in_hdr_wire;
            tmp_sop_nxt   = in_sop_wire;
            tmp_eop_nxt   = in_eop_wire;
            tmp_valid_nxt = in_valid_wire;
        end
        // 输入到读输出
        if (in_to_r) begin
            r_out_data_nxt  = in_data_wire;
            r_out_hdr_nxt   = in_hdr_wire;
            r_out_sop_nxt   = in_sop_wire;
            r_out_eop_nxt   = in_eop_wire;
            r_out_valid_nxt = in_valid_wire;
        end
        // 输入到写输出
        if (in_to_r) begin
            w_out_data_nxt  = in_data_wire;
            w_out_hdr_nxt   = in_hdr_wire;
            w_out_sop_nxt   = in_sop_wire;
            w_out_eop_nxt   = in_eop_wire;
            w_out_valid_nxt = in_valid_wire;
        end
        // 缓存到读输出
        if (tmp_to_r) begin
            r_out_data_nxt  = tmp_data;
            r_out_hdr_nxt   = tmp_hdr;
            r_out_sop_nxt   = tmp_sop;
            r_out_eop_nxt   = tmp_eop;
            r_out_valid_nxt = tmp_valid;
        end
        // 缓存到写输出
        if (tmp_to_w) begin
            w_out_data_nxt  = tmp_data;
            w_out_hdr_nxt   = tmp_hdr;
            w_out_sop_nxt   = tmp_sop;
            w_out_eop_nxt   = tmp_eop;
            w_out_valid_nxt = tmp_valid;
        end
        //
        // if (shut_w) begin
        //     w_out_valid_nxt = 0;
        // end
        // //
        // if (shut_r) begin
        //     r_out_valid_nxt = 0;
        // end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
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
            tmp_data  <= tmp_data_nxt;
            tmp_hdr   <= tmp_hdr_nxt;
            tmp_sop   <= tmp_sop_nxt;
            tmp_eop   <= tmp_eop_nxt;
            tmp_valid <= tmp_valid_nxt;
            
            r_out_data  <= r_out_data_nxt;
            r_out_hdr   <= r_out_hdr_nxt;
            r_out_sop   <= r_out_sop_nxt;
            r_out_eop   <= r_out_eop_nxt;
            r_out_valid <= r_out_valid_nxt & !shut_r;
            
            w_out_data  <= w_out_data_nxt;
            w_out_hdr   <= w_out_hdr_nxt;
            w_out_sop   <= w_out_sop_nxt;
            w_out_eop   <= w_out_eop_nxt;
            w_out_valid <= w_out_valid_nxt & !shut_w;
        end
    end
    
endmodule
