`timescale 1ns/1ps
module tb_wr_tlp_axi();
    
    parameter DOUBLE_WORD       = 32;
    parameter HEADER_SIZE       = 4*DOUBLE_WORD;
    parameter TLP_DATA_WIDTH    = 8*DOUBLE_WORD;
    parameter AXI_DATA_WIDTH    = TLP_DATA_WIDTH;
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8;
    parameter AXI_ADDR_WIDTH    = 64;
    parameter AXI_ID_WIDTH      = 8;
    parameter AXI_MAX_BURST_LEN = 256;
    
    reg                                                     clk;
    reg                                                     rst_n;
    // tlp
    wire                                                    tlp_ready;
    wire                                                    tlp_valid;
    wire                    [TLP_DATA_WIDTH-1:0]            tlp_data;
    wire                    [HEADER_SIZE-1:0]               tlp_hdr;
    wire                                                    tlp_sop;
    wire                                                    tlp_eop;
    // axi aw
    reg                                                     axi_awready,axi_awready_nxt;
    wire                                                    axi_awvalid;
    wire                    [AXI_ID_WIDTH-1 :0]             axi_awid;
    wire                    [AXI_ADDR_WIDTH-1:0]            axi_awaddr;
    wire                    [7:0]                           axi_awlen;
    wire                    [2:0]                           axi_awsize;
    wire                    [1:0]                           axi_awburst;
    wire                                                    axi_awlock;
    wire                    [3:0]                           axi_awcache;
    wire                    [2:0]                           axi_awprot;
    // axi w
    reg                                                     axi_wready,axi_wready_nxt;
    wire                                                    axi_wvalid;
    wire                    [AXI_DATA_WIDTH-1:0]            axi_wdata;
    wire                    [AXI_STRB_WIDTH-1:0]            axi_wstrb;
    wire                                                    axi_wlast;
    // axi b
    wire                                                    axi_bready;
    reg                                                     axi_bvalid;
    reg                     [AXI_ID_WIDTH-1:0]              axi_bid;
    reg                     [1:0]                           axi_bresp;
    // other
    wire                                                    tlp_error;
    
    initial begin
        clk            = 0;
        axi_bvalid     = 1'b1;
        axi_bid        = 0;
        axi_bresp      = 0;
        forever #1 clk = ~clk;
    end
    initial begin
        rst_n    = 1;
        #5 rst_n = 0;
        #5;
        // @(posedge clk);
        rst_n = 1;
    end
    always @* begin
        axi_awready_nxt = 1'b1;
        axi_wready_nxt  = 1'b1;
        if (axi_awvalid & axi_awready) begin
            axi_awready_nxt = 0;
        end
        
        if (axi_wready & axi_wvalid) begin
            axi_wready_nxt = 0;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_awready <= 1;
            axi_wready  <= 1;
        end
        else begin
            axi_awready <= axi_awready_nxt;
            axi_wready  <= axi_wready_nxt;
        end
    end
    
    tlp_tx #(
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH)
    ) tlp_tx (
        .clk(clk),
        .rst_n(rst_n),
        .in_ready(tlp_ready),
        .in_data(tlp_data),
        .in_hdr(tlp_hdr),
        .in_sop(tlp_sop),
        .in_eop(tlp_eop),
        .in_valid(tlp_valid)
    );
    
    wr_tlp_axi #(
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN)
    ) wr_tlp_axi_ins (
        .clk(clk),
        .rst_n(rst_n),
        .tlp_hdr(tlp_hdr),
        .tlp_data(tlp_data),
        .tlp_sop(tlp_sop),
        .tlp_eop(tlp_eop),
        .tlp_valid(tlp_valid),
        .tlp_ready(tlp_ready),
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
        .tlp_error(tlp_error)
    );
endmodule
