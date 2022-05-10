module pcie_axi_m #(
    PORTS                   =        2,
    DOUBLE_WORD             =        32,
    HEADER_SIZE             =        4*DOUBLE_WORD,
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD,
    TLP_STRB_WIDTH          =        TLP_DATA_WIDTH/8,
    AXI_DATA_WIDTH          =        TLP_DATA_WIDTH,
    AXI_ADDR_WIDTH          =        64,
    AXI_STRB_WIDTH          =        AXI_DATA_WIDTH/8,
    AXI_ID_WIDTH            =        8,
    AXI_MAX_BURST_LEN       =        256
) (
    input                                                   clk,
    input                                                   rst_n,

    // requester TLP input 
    input                   [TLP_DATA_WIDTH-1:0]            req_tlp_data,
    input                   [HEADER_SIZE-1:0]               req_tlp_hdr,
    input                   [TLP_STRB_WIDTH-1:0]            req_tlp_strb,
    input                                                   req_tlp_sop,
    input                                                   req_tlp_eop,
    input                                                   req_tlp_valid,
    output                                                  req_tlp_ready,

    // completer TLP output
    output                  [TLP_DATA_WIDTH-1:0]            cpl_tlp_data,
    output                  [HEADER_SIZE-1:0]               cpl_tlp_hdr,
    output                  [TLP_STRB_WIDTH-1:0]            cpl_tlp_strb,
    output                                                  cpl_tlp_sop,
    output                                                  cpl_tlp_eop,
    output                                                  cpl_tlp_valid,
    input                                                   cpl_tlp_ready,

    // AXI AW
    output                  [AXI_ID_WIDTH-1:0]              axi_awid,
    output                  [AXI_ADDR_WIDTH-1:0]            axi_awaddr,
    output                  [7:0]                           axi_awlen,
    output                  [2:0]                           axi_awsize,
    output                  [1:0]                           axi_awburst,
    output                  [2:0]                           axi_awprot,
    output                  [3:0]                           axi_awcache,
    output                                                  axi_awlock,
    output                                                  axi_awvalid,
    input                                                   axi_awready,

    // AXI W
    output                  [AXI_DATA_WIDTH-1:0]            axi_wdata,
    output                  [AXI_STRB_WIDTH-1:0]            axi_wstrb,
    output                                                  axi_wlast,
    output                                                  axi_wvalid,
    input                                                   axi_wready,

    // AXI B
    input                   [AXI_ID_WIDTH-1:0]              axi_bid,
    input                   [1:0]                           axi_bresp,
    input                                                   axi_bvalid,
    output                                                  axi_bready,

    // AXI AR
    output                  [AXI_ID_WIDTH-1:0]              axi_arid,
    output                  [AXI_ADDR_WIDTH-1:0]            axi_araddr,
    output                  [7:0]                           axi_arlen,
    output                  [2:0]                           axi_arsize,
    output                  [1:0]                           axi_arburst,
    output                  [3:0]                           axi_arcache,
    output                                                  axi_arlock,
    output                  [2:0]                           axi_arprot,
    output                                                  axi_arvalid,
    input                                                   axi_arready,

    // AXI R
    input                   [AXI_DATA_WIDTH-1:0]            axi_rdata,
    input                   [AXI_STRB_WIDTH-1:0]            axi_rstrb,
    input                                                   axi_rlast,
    input                                                   axi_rvalid,
    output                                                  axi_rready,

    // control
    input                                                   demux_en,
    input                 [15:0]                            completer_id,
    output                                                  tlp_error
);
    wire                    [HEADER_SIZE-1:0]               w_out_hdr;
    wire                    [TLP_DATA_WIDTH-1:0]            w_out_data;
    wire                                                    w_out_strb;
    wire                                                    w_out_sop;
    wire                                                    w_out_eop;
    wire                                                    w_out_valid;
    wire                                                    w_out_ready;
    wire                    [HEADER_SIZE-1:0]               r_out_hdr;
    wire                    [TLP_DATA_WIDTH-1:0]            r_out_data;
    wire                                                    r_out_strb;
    wire                                                    r_out_sop;
    wire                                                    r_out_eop;
    wire                                                    r_out_valid;
    wire                                                    r_out_ready;
    wire                                                    w_tlp_error;
    wire                                                    r_tlp_error;
    assign tlp_error = w_tlp_error | r_tlp_error;
    // tlp解复用
    tlp_demux #(
        .PORTS(PORTS),
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
        .TLP_STRB_WIDTH(TLP_STRB_WIDTH)
    ) tlp_demux_ins (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(req_tlp_data),
        .in_hdr(req_tlp_hdr),
        .in_strb(req_tlp_strb),
        .in_sop(req_tlp_sop),
        .in_eop(req_tlp_eop),
        .in_valid(req_tlp_valid),
        .in_ready(req_tlp_ready),
        .r_out_data(r_out_data),
        .r_out_hdr(r_out_hdr),
        .r_out_strb(r_out_strb),
        .r_out_sop(r_out_sop),
        .r_out_eop(r_out_eop),
        .r_out_valid(r_out_valid),
        .r_out_ready(r_out_ready),
        .w_out_data(w_out_data),
        .w_out_hdr(w_out_hdr),
        .w_out_strb(w_out_strb),
        .w_out_sop(w_out_sop),
        .w_out_eop(w_out_eop),
        .w_out_valid(w_out_valid),
        .w_out_ready(w_out_ready),
        .enable(demux_en)
    );
    
    wr_tlp_axi #(
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
        .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN)
    ) wr_tlp_axi_ins (
        .clk(clk),
        .rst_n(rst_n),
        .tlp_hdr(w_out_hdr),
        .tlp_data(w_out_data),
        .tlp_strb(w_out_strb),
        .tlp_sop(w_out_sop),
        .tlp_eop(w_out_eop),
        .tlp_valid(w_out_valid),
        .tlp_ready(w_out_ready),
        .axi_awid(axi_awid),
        .axi_awaddr(axi_awaddr),
        .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize),
        .axi_awburst(axi_awburst),
        .axi_awlock(axi_awlock),
        .axi_awcache(axi_awcache),
        .axi_awprot(axi_awprot),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),
        .axi_wvalid(axi_wvalid),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_wready(axi_wready),
        .axi_bid(axi_bid),
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .tlp_error(w_tlp_error)
    );
    
    rd_tlp_axi #(
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
        .TLP_STRB_WIDTH(TLP_STRB_WIDTH)
    ) rd_tlp_axi_ins (
        .clk(clk),
        .rst_n(rst_n),
        .req_tlp_hdr(r_out_hdr),
        .req_tlp_sop(r_out_sop),
        .req_tlp_eop(r_out_eop),
        .req_tlp_valid(r_out_valid),
        .req_tlp_ready(r_out_ready),
        .cpl_tlp_hdr(cpl_tlp_hdr),
        .cpl_tlp_strb(cpl_tlp_strb),
        .cpl_tlp_data(cpl_tlp_data),
        .cpl_tlp_sop(cpl_tlp_sop),
        .cpl_tlp_eop(cpl_tlp_eop),
        .cpl_tlp_valid(cpl_tlp_valid),
        .cpl_tlp_ready(cpl_tlp_ready),
        .axi_arid(axi_arid),
        .axi_araddr(axi_araddr),
        .axi_arsize(axi_arsize),
        .axi_arlen(axi_arlen),
        .axi_arburst(axi_arburst),
        .axi_arprot(axi_arprot),
        .axi_arlock(axi_arlock),
        .axi_arcache(axi_arcache),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rstrb(axi_rstrb),
        .axi_rlast(axi_rlast),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .completer_id(completer_id),
        .tlp_error(r_tlp_error)
    );
    
endmodule
