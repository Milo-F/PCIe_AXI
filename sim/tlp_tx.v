module tlp_tx #(
    DOUBLE_WORD             =        32,                                // 双字，32位
    HEADER_SIZE             =        4*DOUBLE_WORD,                     // Header4个双字，取决于host内存空间是否大于4GB
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD                      // 数据荷载8个双字
)(
    input                                                   clk,
    input                                                   rst_n,
    input                                                   in_ready,
    output      reg         [TLP_DATA_WIDTH-1:0]            in_data,
    output      reg         [HEADER_SIZE-1:0]               in_hdr,
    output      reg                                         in_sop,
    output      reg                                         in_eop,
    output      reg                                         in_valid
);
    reg                     [TLP_DATA_WIDTH-1:0]            in_data_nxt;
    reg                     [HEADER_SIZE-1:0]               in_hdr_nxt;
    reg                                                     in_sop_nxt;
    reg                                                     in_eop_nxt;
    reg                                                     in_valid_nxt;
    
    reg                     [9:0]                           cnt,cnt_nxt;
    wire                    [9:0]                           cnt_minus1;
    assign cnt_minus1 = cnt - 1'b1;
    reg                                                     finish,finish_nxt;
    reg                     [2:0]                           r_w_cnt,r_w_cnt_nxt;
    parameter [9:0] TLP_NUM    = 16; // 正常传输
    // parameter [9:0] TLP_NUM = 1; // 单次传输
    always @* begin
        in_hdr_nxt          = in_hdr;
        in_hdr_nxt[127:125] = 3'b011; // fmt wr TLP
        // in_hdr_nxt[126]     = r_w_cnt[2] ? 1 : 0; // 随机读写
        r_w_cnt_nxt = r_w_cnt;
        in_hdr_nxt[105:96]  = TLP_NUM<<3; // length
        in_data_nxt         = in_data;
        in_valid_nxt        = in_valid;
        cnt_nxt             = cnt;
        in_sop_nxt          = in_sop;
        in_eop_nxt          = in_eop;
        finish_nxt          = finish;
        
        if (cnt == TLP_NUM) begin
            in_sop_nxt = 1'b1;
        end
        
        if (cnt == 1) begin
            in_eop_nxt = 1'b1;
        end
        
        if (!in_valid) begin
            in_valid_nxt = 1'b1;
            in_data_nxt  = in_data + 1'b1;
            r_w_cnt_nxt = r_w_cnt - 1'b1;
        end
        
        if (in_valid & in_ready) begin
            cnt_nxt      = cnt_minus1;
            in_valid_nxt = 0;
            in_sop_nxt   = 0;
            in_eop_nxt   = 0;
            if (in_eop) begin
                finish_nxt = 0;
            end
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            in_hdr    <= 0; // 对齐地址测试
            // in_hdr <= {0,3'b100}; // 非对齐地址测试
            in_data   <= 0;
            in_sop    <= 0;
            in_eop    <= 0;
            in_valid  <= 0;
            cnt       <= TLP_NUM;
            finish    <= 1'b1;
            r_w_cnt <= 0;
        end
        else begin
            in_hdr   <= in_hdr_nxt;
            in_data  <= in_data_nxt&{TLP_DATA_WIDTH{finish}};
            in_sop   <= in_sop_nxt;
            in_eop   <= in_eop_nxt;
            in_valid <= in_valid_nxt & finish;
            cnt      <= cnt_nxt;
            r_w_cnt <= r_w_cnt_nxt;
            finish   <= finish_nxt;
        end
    end
endmodule
