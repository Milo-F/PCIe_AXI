#dut language
DUT_LANG ?= verilog

# testbench language
TB_LANG ?= systemverilog

# extra parameters
COM_P ?= 
RUN_P ?= 
CLR_P ?= 

# log file name
COM_LOG ?= com.log
SIM_LOG ?= sim.log

# compile options setting
COM := com
VCS := vcs
COM_OP := -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed
COM_F ?= filelist.f
OUT_F ?= simv
ifeq ($(DUT_LANG), verilog)
	COM_OP += +v2k
endif
ifeq ($(TB_LANG), systemverilog)
	COM_OP += -sverilog
endif
DEBUG_OP ?= -debug_all -fsdb
UCLI ?= -ucli
VERDI_OP = -lca -kdb
INCDIR ?= rtl/

$(COM):
	@$(VCS) $(COM_OP) $(DEBUG_OP) -f $(COM_F) $(UCLI) $(VERDI_OP) -l $(COM_LOG) -o $(OUT_F) $(COM_P) +incdir+$(INCDIR)

# run simulation
RUN := run
GUI ?= -gui=verdi
$(RUN):
	./$(OUT_F) $(GUI) -l $(SIM_LOG) $(RUN_P) &
# clear
CLR = clr
CLR_F ?= simv* DVEfiles *.vpd *.dump csrc libnz4w_r.soLog *.sim *.mra *.log ucli.key session* *.db vcs.key urgReport *.h log *.txt scsim* WORK/* text inter* novas* verdiLog _vcs_cp_*
$(CLR):
	@rm -rf $(CLR_F) $(CLR_P)
