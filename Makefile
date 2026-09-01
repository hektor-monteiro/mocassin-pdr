# standard
FC = mpif90.openmpi
LD = mpif90.openmpi

#IBM
#FC = mpxlf90_r
#LD = mpxlf90_r
#FFLAGS += -O3 -qstrict -qrealsize=4 -bmaxdata:0x40000000 -qmaxmem=-1 -cpp -DPREFIX=\"$(PREFIX)\"

#SUN
#FC = mpf90
#LD = mpf90
#FFLAGS += -fast -xarch=v9b -ftrap=%none -lmpi -cpp -DPREFIX=\"$(PREFIX)\"

#SGI
#FC = f90
#LD = f90
#FFLAGS += -64 -C -mpio -OPT:Olimit=3495 -O3 -lmpi -cpp -DPREFIX=\"$(PREFIX)\"

# set prefix depending on OS
OS := $(shell uname)
ifeq ($(OS),Darwin)
  PREFIX=/usr/local
else
  #PREFIX=$(HOME)/mocassin_2023
  PREFIX=$(HOME)/.local
endif

# get version from changelog if debian package, or git log otherwise
VERSION := $(shell if [ -e debian/ ]; then dpkg-parsechangelog -S version; elif [ "`command -v git`" != "" ]; then git describe --always --tags --dirty; else echo "2.0.73"; fi)

# set flags

ifeq ($(FC),ifort)
  FFLAGS += -cpp -DPREFIX=\"$(PREFIX)\" -DVERSION=\"$(VERSION)\" -module source/
else
  FFLAGS += -cpp -Jsource/ -ffree-line-length-0 -lm -DPREFIX=\"$(PREFIX)\" -DVERSION=\"$(VERSION)\" -I/usr/local/include -std=legacy 
endif

MANDIR=$(DESTDIR)$(PREFIX)/share/man/man1
SOURCES = source/constants_mod.o source/vector_mod.o source/common_mod.o source/interpolation_mod.o \
	source/set_input_mod.o source/hydro_mod.o source/ph_mod.o source/composition_mod.o \
	source/continuum_mod.o source/ionization_mod.o source/pathIntegration_mod.o \
	source/grid_mod.o source/dust_mod.o source/emission_mod.o source/photon_mod.o  \
	source/update_mod.o source/output_mod.o $(PDR_BRIDGE) source/iteration_mod.o source/readdata_mod.o

# PDR support (DEVLOG D-009, D-020). Off by default: with PDR unset the build is
# semantically identical to a plain build (verified by masking the source-line
# immediates gfortran bakes into I/O statements - see D-017).
CC ?= gcc
SUNDIALS_DIR ?= $(HOME)/software/sundials-7.8.0

ifeq ($(PDR),1)
  FFLAGS += -DPDR

  # Frozen 3D-PDR preprocessor matrix (D-009/D-020). Deliberately NOT set:
  #   ONEDIMENSIONAL (3D grids), DUST (MOCASSIN owns dust temperature),
  #   OPENMP (MOCASSIN's MPI already parallelises the cell loop),
  #   CHEMANALYSIS (temp_rate(nreac,ncells) is prohibitive in 3D),
  #   GUESS_TEMP (lives in calc_UVfield, which D-001 removes).
  PDRFLAGS = -DTHERMALBALANCE -DREDUCED -DONEDIMENSIONAL -DH2FORM_CT02 \
             -DCHEMSTEADY -DCHEMRETRY -DFORCECONVERGENCE \
             -DNGACCEL -DNGCYCLE -DNGRELAX -DILLINOIS -DREBRACKET -DSOBOLEV

  PDR_INC = -I$(SUNDIALS_DIR)/include
  # -rpath so the binaries find SUNDIALS without LD_LIBRARY_PATH being set at
  # run time; only SUNDIALS_DIR at build time is then required.
  PDR_LIB = -L$(SUNDIALS_DIR)/lib -Wl,-rpath,$(SUNDIALS_DIR)/lib \
            -lsundials_cvode -lsundials_nvecserial \
            -lsundials_sunmatrixdense -lsundials_sunlinsoldense \
            -lsundials_sunnonlinsolnewton -lsundials_core -lm

  # Module layer first - Fortran module files must exist before their users.
  PDR_MODULES = source/pdr/definitions.o source/pdr/healpix_types.o \
                source/pdr/modules.o source/pdr/m_Mesh.o \
                source/pdr/chemical_heating.o
  # Code layer. Order follows upstream src/makefile.
  PDR_CODE = source/pdr/healpix.o source/pdr/solvlevpop.o \
             source/pdr/read_species.o source/pdr/read_rates.o \
             source/pdr/heapsort.o source/pdr/calc_reac_rates.o \
             source/pdr/shield.o source/pdr/spline.o source/pdr/m_Ray_box.o \
             source/pdr/escape_probability.o source/pdr/eval_points.o \
             source/pdr/heatingfunctions.o source/pdr/find_Ccoeff.o \
             source/pdr/read_input.o source/pdr/read_coolants.o \
             source/pdr/initialization.o source/pdr/changetemperature.o \
             source/pdr/CRattenuation.o source/pdr/columndensity.o \
             source/pdr/partition_function.o source/pdr/lte_population.o \
             source/pdr/allocations.o source/pdr/chemicaliterations.o \
             source/pdr/updatelte.o source/pdr/coolingfunctions.o \
             source/pdr/checkconvergence.o source/pdr/ng_acceleration.o \
             source/pdr/h2_form.o
  # C layer: CVODE driver plus the ODE right-hand side for the chosen network.
  PDR_C = source/pdr/calculate_abundances.o source/pdr/odes_reduced.o

  PDR_OBJ = $(PDR_MODULES) $(PDR_CODE) $(PDR_C)
  # The bridge is MOCASSIN code but uses the vendored modules, so it slots into
  # SOURCES after output_mod and before iteration_mod (which will call it in
  # Phase 4). Empty when PDR is off, so SOURCES is unchanged.
  PDR_BRIDGE = source/pdr_mod.o
  LDFLAGS += $(PDR_LIB)
endif

# Fortran module dependencies. The Makefile expresses none, so editing a
# foundational module leaves its dependents compiling against a stale .mod and
# failing with "Mismatch in components of derived type" - which reads like a
# source error, not a build-order one. constants_mod and common_mod are the two
# every other unit uses; making everything depend on them removes the common
# case. (Same class as the flag staleness of D-023.)
# common_mod itself needs constants_mod and vector_mod, so the base layer is
# those three in that order.
MODBASE = source/constants_mod.o source/vector_mod.o source/common_mod.o
$(filter-out $(MODBASE),$(SOURCES) $(PDR_BRIDGE) source/mocassin.o \
  source/mocassinWarm.o source/mocassinOutput.o source/mocassinPlot.o): $(MODBASE)
source/common_mod.o: source/constants_mod.o source/vector_mod.o
source/vector_mod.o: source/constants_mod.o

# Same for the vendored tree: every 3D-PDR unit uses maincode_module, so a
# change there must rebuild all of them. Without this, editing modules.F90
# leaves objects compiled against the old declarations - and for something like
# a character length that produces no error at all, just silently truncated
# strings at run time (DEVLOG D-028).
PDRBASE = source/pdr/definitions.o source/pdr/healpix_types.o source/pdr/modules.o
$(filter-out $(PDRBASE),$(PDR_OBJ) $(PDR_BRIDGE)): $(PDRBASE)
source/pdr/modules.o: source/pdr/definitions.o source/pdr/healpix_types.o
source/pdr/healpix_types.o: source/pdr/definitions.o

ifeq ($(CO),debug) #to show all compiler warnings
  FFLAGS += -fbounds-check -Wall -Wuninitialized -g -pg #-ffpe-trap=zero,overflow,invalid,underflow,denormal -fbacktrace -fcheck=all
else ifeq ($(CO),valgrind)
  FFLAGS += -g
else ifeq ($(CO),gprof)
  FFLAGS += -g -O0
else
#  FFLAGS += -O3 -fbacktrace -Wall -fcheck=all -fopt-info -fopt-info-missed -march=native -mtune=native -fomit-frame-pointer -fopenmp
  FFLAGS += -O2
endif

.PHONY: all clean new install uninstall

all: mocassin mocassinWarm mocassinOutput mocassinPlot

# Phase 1 chemistry smoke test (DEVLOG D-020). PDR=1 only; needs no MOCASSIN grid.
pdrSmokeTest: $(PDR_OBJ) source/pdrSmokeTest.o
	$(LD) $(FFLAGS) $(PDRFLAGS) -o $@ $^ $(LDFLAGS)

new: clean all

# Every object also depends on the Makefile: changing a compile rule or a flag
# otherwise leaves stale objects that look up to date, which shows up much later
# as a confusing runtime mismatch rather than a build error.
#
# Toggling PDR changes the preprocessor flags, but the .o files look up to date
# to make and are silently reused - which produces .mod files missing the guarded
# symbols. Stamp the current value and make every object depend on it, so
# switching the flag forces a rebuild instead of a confusing compile error.
.pdrflag: FORCE
	@[ -f $@ ] && [ "`cat $@`" = "$(PDR)" ] || echo "$(PDR)" > $@
FORCE:
.PHONY: FORCE

%.o: %.f90 .pdrflag Makefile
	$(FC) $(FFLAGS) $< -c -o $@

# Vendored 3D-PDR sources (DEVLOG D-005). .F90 is upstream's capitalisation and
# carries its own preprocessor matrix; the C files need the SUNDIALS headers.
# The bridge tests the compiled-in network with #ifdef REDUCED etc., so it needs
# PDRFLAGS as well as FFLAGS - the generic %.o rule carries only the latter.
source/pdr_mod.o: source/pdr_mod.f90 .pdrflag Makefile
	$(FC) $(FFLAGS) $(PDRFLAGS) $< -c -o $@

source/pdrSmokeTest.o: source/pdrSmokeTest.f90 .pdrflag Makefile
	$(FC) $(FFLAGS) $(PDRFLAGS) $< -c -o $@

source/pdr/%.o: source/pdr/%.F90 .pdrflag Makefile
	$(FC) $(FFLAGS) $(PDRFLAGS) $< -c -o $@

source/pdr/%.o: source/pdr/%.c .pdrflag Makefile
	$(CC) -O2 $(PDRFLAGS) $(PDR_INC) $< -c -o $@

mocassin: $(PDR_OBJ) $(SOURCES) source/mocassin.o
	$(LD) $(FFLAGS) -o $@ $^ $(LDFLAGS)

mocassinWarm: $(PDR_OBJ) $(SOURCES) source/mocassinWarm.o
	$(LD) $(FFLAGS) -o $@ $^ $(LDFLAGS)

mocassinOutput: $(PDR_OBJ) $(SOURCES) source/mocassinOutput.o
	$(LD) $(FFLAGS) -o $@ $^ $(LDFLAGS)

mocassinPlot: $(PDR_OBJ) $(SOURCES) source/mocassinPlot.o
	$(LD) $(FFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	/bin/rm -f source/*.o *~ source/*.mod source/pdr/*.o .pdrflag pdrSmokeTest mocassin mocassinWarm mocassinOutput mocassinPlot

install: mocassin mocassinWarm mocassinOutput mocassinPlot
	test -e $(DESTDIR)$(PREFIX)/share/mocassin || mkdir -p $(DESTDIR)$(PREFIX)/share/mocassin
	test -e $(DESTDIR)$(PREFIX)/share/doc/mocassin || mkdir -p $(DESTDIR)$(PREFIX)/share/doc/mocassin
	test -e $(DESTDIR)$(PREFIX)/bin || mkdir -p $(DESTDIR)$(PREFIX)/bin
	test -e $(MANDIR) || mkdir -p $(MANDIR)
	cp -R data $(DESTDIR)$(PREFIX)/share/mocassin
	cp -R dustData $(DESTDIR)$(PREFIX)/share/mocassin
	cp -R dataPDR $(DESTDIR)$(PREFIX)/share/mocassin
	cp -R benchmarks $(DESTDIR)$(PREFIX)/share/mocassin
	cp -R examples $(DESTDIR)$(PREFIX)/share/doc/mocassin
	install -m 644 man/mocassin.1 $(MANDIR)
	gzip -f $(MANDIR)/mocassin.1
	ln -s -f $(MANDIR)/mocassin.1.gz $(MANDIR)/mocassinWarm.1.gz
	ln -s -f $(MANDIR)/mocassin.1.gz $(MANDIR)/mocassinOutput.1.gz
	ln -s -f $(MANDIR)/mocassin.1.gz $(MANDIR)/mocassinPlot.1.gz
	install mocassin $(DESTDIR)$(PREFIX)/bin
	install mocassinWarm $(DESTDIR)$(PREFIX)/bin
	install mocassinPlot $(DESTDIR)$(PREFIX)/bin
	install mocassinOutput $(DESTDIR)$(PREFIX)/bin

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/mocassin
	rm -f $(DESTDIR)$(PREFIX)/bin/mocassinOutput
	rm -f $(DESTDIR)$(PREFIX)/bin/mocassinPlot
	rm -f $(DESTDIR)$(PREFIX)/bin/mocassinWarm
	rm -f $(MANDIR)/mocassin.1.gz
	rm -f $(MANDIR)/mocassinOutput.1.gz
	rm -f $(MANDIR)/mocassinPlot.1.gz
	rm -f $(MANDIR)/mocassinWarm.1.gz
	rm -rf $(DESTDIR)$(PREFIX)/share/mocassin
	rm -rf $(DESTDIR)$(PREFIX)/share/doc/mocassin
