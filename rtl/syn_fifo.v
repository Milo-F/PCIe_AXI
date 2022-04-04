/*----------------------------------------
 *    File Name: rtl/syn_fifo.v
 *    function: 同步FIFO，
 *    author: Milo
 *    Data: 2022-03-22
 *    Version: 1.0
----------------------------------------*/

module syn_fifo #(
    DATA_WIDTH              =        8,
    FIFO_DEPTH              =        16,
    ADDR_WIDTH              =        4
) (
    input                                                   clk,
    input                                                   rst_n,
    input                                                   w_en,
    input                   [DATA_WIDTH - 1 : 0]            w_data,
    input                                                   r_en,
    output                  [DATA_WIDTH - 1 : 0]            r_data,
    output                                                  is_empty,
    output                                                  is_full,
    output                  [ADDR_WIDTH : 0]                room_avail,
    output                  [ADDR_WIDTH : 0]                data_avail
);
    // flip-flop output
    // reg         [DATA_WIDTH - 1 : 0]    r_data, r_data_nxt;
    reg                     [ADDR_WIDTH : 0]                room_avail,room_avail_nxt;
    reg                     [ADDR_WIDTH : 0]                data_avail,data_avail_nxt;
    reg                                                     is_empty,is_empty_nxt;
    reg                                                     is_full,is_full_nxt;
    // write and read pointer
    reg                     [ADDR_WIDTH : 0]                w_ptr,w_ptr_nxt;
    reg                     [ADDR_WIDTH : 0]                r_ptr,r_ptr_nxt;
    // avaliable room counter
    // reg         [ADDR_WIDTH : 0]            avail_tmp;
    
    // write pointer control
    always @* begin
        w_ptr_nxt = w_ptr;
        if (w_en) begin
            w_ptr_nxt = w_ptr + 1'b1;
        end
    end
    
    // read pointer control
    always @* begin
        r_ptr_nxt = r_ptr;
        if (r_en) begin
            r_ptr_nxt = r_ptr + 1'b1;
        end
    end
    
    // empty or full control
    always @* begin
        is_empty_nxt = 0;
        is_full_nxt  = 0;
        if (w_ptr[ADDR_WIDTH - 1 : 0] == r_ptr[ADDR_WIDTH - 1 : 0]) begin
            if (w_ptr[ADDR_WIDTH] ^ r_ptr[ADDR_WIDTH]) begin
                is_full_nxt = 1'b1;
            end
            else begin
                is_empty_nxt = 1'b1;
            end
        end
    end
    
    // avaliable room or data calculate
    always @* begin
        room_avail_nxt = room_avail;
        data_avail_nxt = data_avail;
        // avail_tmp = w_ptr[ADDR_WIDTH - 1 : 0] - r_ptr[ADDR_WIDTH - 1 : 0]
        if (w_ptr[ADDR_WIDTH - 1 : 0] > r_ptr[ADDR_WIDTH - 1 : 0]) begin
            data_avail_nxt = w_ptr[ADDR_WIDTH - 1 : 0] - r_ptr[ADDR_WIDTH - 1 : 0];
            room_avail_nxt = FIFO_DEPTH - w_ptr[ADDR_WIDTH - 1 : 0] + r_ptr[ADDR_WIDTH - 1 : 0];
        end
        else begin
            if (w_ptr[ADDR_WIDTH - 1 : 0] < r_ptr[ADDR_WIDTH - 1 : 0]) begin
                data_avail_nxt = -(w_ptr[ADDR_WIDTH - 1 : 0] - r_ptr[ADDR_WIDTH - 1 : 0]);
                room_avail_nxt = FIFO_DEPTH + w_ptr[ADDR_WIDTH - 1 : 0] - r_ptr[ADDR_WIDTH - 1 : 0];
            end
            else begin
                if (w_ptr[ADDR_WIDTH - 1 : 0] == r_ptr[ADDR_WIDTH - 1 : 0]) begin
                    data_avail_nxt = !(w_ptr[ADDR_WIDTH] ^ r_ptr[ADDR_WIDTH]) ? 0 : FIFO_DEPTH;
                    room_avail_nxt = (w_ptr[ADDR_WIDTH] ^ r_ptr[ADDR_WIDTH]) ? 0 : FIFO_DEPTH;
                end
            end
        end
    end
    
    // update regs
    always @(posedge clk) begin
        if (!rst_n) begin
            w_ptr      <= 0;
            r_ptr      <= 0;
            is_full    <= 0;
            is_empty   <= 1'b1;
            room_avail <= FIFO_DEPTH;
            data_avail <= 0;
        end
        else begin
            w_ptr      <= w_ptr_nxt;
            r_ptr      <= r_ptr_nxt;
            is_full    <= is_full_nxt;
            is_empty   <= is_empty_nxt;
            room_avail <= room_avail_nxt;
            data_avail <= data_avail_nxt;
        end
    end
    
    // ram instance
    fifo_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) fifo_ram_ins (
        .w_clk(clk),
        .r_clk(clk),
        .rst_n(rst_n),
        .r_en(r_en),
        .r_addr(r_ptr[ADDR_WIDTH - 1 : 0]),
        .r_data(r_data),
        .w_en(w_en),
        .w_addr(w_ptr[ADDR_WIDTH - 1 : 0]),
        .w_data(w_data)
    );
    
endmodule
