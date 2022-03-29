/*
 * @Author=Milo
 * @Function= pcie事务包读写解复用器，将读请求tlp与写请求tlp区分分别输出
 */

module tlp_demux #(
    PORTS                   =        2,                                  // 解复用输出端口，在此解复用器用作读写复用，故为2
    DOUBLE_WORD             =        32,                                 // 双字，32位
    HEADER_SIZE             =        4*DOUBLE_WORD,                      // Header4个双字，取决于host内存空间是否大于4GB
    PAYLOAD_SIZE            =        8*DOUBLE_WORD                       // 数据荷载8个双字
) (
    input       wire                                        clk,
    input       wire                                        rst_n,
    input       wire        [PAYLOAD_SIZE-1:0]              in_data,     // 输入TLP包数据
    input       wire        [HEADER_SIZE-1:0]               in_hdr,      // 输入TLP包头
    input       wire                                        in_sop,
    input       wire                                        in_eop,
    input       wire                                        in_valid,
    output      reg                                         in_ready,
    output      reg         [PAYLOAD_SIZE-1:0]              r_out_data,  // 输出读请求TLP包
    output      reg         [HEADER_SIZE-1:0]               r_out_hdr,
    output      reg                                         r_out_sop,
    output      reg                                         r_out_eop,
    output      reg                                         r_out_valid,
    input                                                   r_out_ready,
    output      reg         [PAYLOAD_SIZE-1:0]              w_out_data,  // 输出写请求TLP包
    output      reg         [HEADER_SIZE-1:0]               w_out_hdr,
    output      reg                                         w_out_sop,
    output      reg                                         w_out_eop,
    output      reg                                         w_out_valid,
    input       wire                                        w_out_ready,
    input       wire                                        enable
);
    reg                                                     in_ready_nxt;
    /*
     * 输出读请求TLP
     */
    reg                     [PAYLOAD_SIZE-1:0]              r_out_data_nxt;
    reg                     [HEADER_SIZE-1:0]               r_out_hdr_nxt;
    reg                                                     r_out_sop_nxt;
    reg                                                     r_out_eop_nxt;
    reg                                                     r_out_valid_nxt;
    /*
     * 输出写请求TLP
     */
    reg                     [PAYLOAD_SIZE-1:0]              w_out_data_nxt;
    reg                     [HEADER_SIZE-1:0]               w_out_hdr_nxt;
    reg                                                     w_out_sop_nxt;
    reg                                                     w_out_eop_nxt;
    reg                                                     w_out_valid_nxt;
    /*
     * 输入TLP筛选，主要控制valid信号，筛除不合格的TLP
     */
    wire                    [PAYLOAD_SIZE-1:0]              in_data_wire;
    wire                    [HEADER_SIZE-1:0]               in_hdr_wire;
    wire                                                    in_sop_wire;
    wire                                                    in_eop_wire;
    wire                                                    in_valid_wire;
    // wire                                                     in_ready_wire;
    /*
     * 内部TLP缓存，
     */
    reg                     [PAYLOAD_SIZE-1:0]              tmp_data;
    reg                     [HEADER_SIZE-1:0]               tmp_hdr;
    reg                                                     tmp_sop;
    reg                                                     tmp_eop;
    reg                                                     tmp_valid;
    reg                                                     tmp_ready;
    
    /*
     * 输入TLP包筛选控制，提取读写标识
     */
    // reg                                                     drop,drop_nxt;
    // reg                                                     frame,frame_nxt;
    wire                                                    wr_rd;    // TLP为写类型：1；TLP为读类型：0
    wire                                                    islegal;
    localparam RD_FMT_TYPE = 8'b010_00000;
    localparam WR_FMT_TYPE = 8'b011_00000;
    // 判断输入TLP是否为存储区读写TLP
    assign islegal = (in_hdr[HEADER_SIZE-:8] == RD_FMT_TYPE) || (in_hdr[HEADER_SIZE-:8] == WR_FMT_TYPE);
    assign wr_rd   = in_hdr[HEADER_SIZE-2];
    
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
    
    localparam ALL_0_BIT   = 1;
    localparam TMP_W_0_BIT = 2;
    localparam TMP_R_0_BIT = 3;
    localparam TMP_0_BIT   = 4;
    localparam W_R_0_BIT   = 5;
    localparam W_0_BIT     = 6;
    localparam R_0_BIT     = 7;
    localparam ALL_1_BIT   = 8;
    // flags
    reg                     [7:0]                           status,status_nxt;
    reg                                                     in_to_w;
    reg                                                     in_to_r;
    reg                                                     in_to_tmp;
    reg                                                     tmp_to_w;
    reg                                                     tmp_to_r;
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
        case(1'b1)
            state[ALL_0_BIT]: begin
                in_ready_nxt = 1'b1;
                if (in_valid_wire) begin // 输入数据有效
                    in_to_w    = wr_rd; // 写请求
                    in_to_r    = !wr_rd; // 读请求
                    status_nxt = (wr_rd) ? TMP_R_0 : TMP_W_0;
                end
            end
            state[TMP_W_0_BIT]: begin
                in_ready_nxt = 1'b1;
            end
            state[TMP_R_0_BIT]: begin
                in_ready_nxt = 1'b1;
            end
            state[TMP_0_BIT]: begin
                in_ready_nxt = 1'b1;
            end
            state[W_R_0_BIT]: begin
                in_ready_nxt = 1'b1;
            end
            state[W_0_BIT]: begin
                in_ready_nxt = 1'b0;
            end
            state[R_0_BIT]: begin
                in_ready_nxt = 1'b0;
            end
            state[ALL_1_BIT]: begin
                in_ready_nxt = 1'b0;
            end
            default:in_ready_nxt = 1'b0;;
        endcase
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            status   <= 8'b0;
            in_ready <= 1'b0;
        end
        else begin
            status   <= status_nxt;
            in_ready <= in_ready_nxt;
        end
    end
    /*
     * 数据传递
     */
    always @* begin
        //
    end
    
endmodule
