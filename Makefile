TANGLE=tclsh ./scripts/tangle.tcl
ALL=generic

.SUFFIXES: .md .tcl .exp

.md.tcl:
	@$(TANGLE) -R $@ $< > $@
	
.md.exp:
	@$(TANGLE) -R $@ $< > $@

default: all

all: exp

tcl: $(ALL:%=%.tcl) 
exp: $(ALL:%=%.exp)

clean:
	@rm -f *~
	@rm -rf $(ALL:%=%.tcl) $(ALL:%=%.exp)

.PHONY: default all clean test tcl exp

