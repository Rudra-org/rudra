# Invocation:
#      make <target> OPT=<opt> ARCH=<architecture> PROFILE=yes
# Examples:
#	make OPT=-g ARCH=linux PROFILE=yes  # debuggable executable, g++ compiler,                     profiling information
#	make                                # optimized with -O3,    compiler determined from `uname`, no profiling information
#
#

RUDRA_LIB_SRC := $(wildcard src/rudra/io/*.cpp) $(wildcard src/rudra/util/*.cpp)

RUDRA_HOME ?= $(CURDIR)/..
RUDRA_LIB = $(RUDRA_HOME)/lib
RUDRA_INCLUDE = $(RUDRA_HOME)/include

LIB := librudra.so

# If no optimization parameter set then do optimize
# as opposed to compile for debugging
OPT ?= -O3 -g


# Use the architecture of host machine to determine what compiler to use.
# Set CXX and other environment variables expressing the choice.
ifdef ARCH
    arch=$(ARCH)
else
    arch=$(shell uname -p)
    ifeq ($(arch),unknown)
        arch=$(shell uname -m)
    endif
endif

ifeq ($(arch),ppc64)
    # POWER7 (inc. p775)
	CXX = xlC_r
    BLASLIB ?= ESSL
endif

ifeq ($(arch),ppc64le)
    # POWER8 LE
    CXX = xlC_r
endif

# compiler-specific flags
ifeq ($(CXX),xlC_r)
    CXXFLAGS += $(OPT) -q64 -qsmp -qpic -qmkshrobj
else
    # assume g++
    CXXFLAGS += -std=c++0x $(OPT) -w -Wno-strict-aliasing -fPIC -shared

    ifneq (,$(findstring -g,$(OPT)))
         # generate information for printing backtrace
         CXXFLAGS += -rdynamic
    endif
endif

CXXFLAGS += -DNDEBUG

PROFILE ?=
ifdef PROFILE
	# enable CPU profiling with google-perftools
    LDFLAGS += -Wl,--no-as-needed -lprofiler -Wl,--as-needed
endif


# All Target
all: copy_headers install

install: $(LIB) $(RUDRA_LIB) copy_headers
	cp $(LIB) $(RUDRA_LIB)

$(LIB):	$(RUDRA_LIB_SRC)
	$(CXX) $(CXXFLAGS) -I$(RUDRA_INCLUDE) $(RUDRA_LIB_SRC) -o $(LIB)

copy_headers:	src/rudra/*.h src/rudra/io/*.h src/rudra/util/*.h
	mkdir -p $(RUDRA_INCLUDE)/rudra $(RUDRA_INCLUDE)/rudra/io $(RUDRA_INCLUDE)/rudra/util
	cp src/rudra/*.h $(RUDRA_INCLUDE)/rudra
	cp src/rudra/io/*.h $(RUDRA_INCLUDE)/rudra/io/
	cp src/rudra/util/*.h $(RUDRA_INCLUDE)/rudra/util/

TESTSRC := $(wildcard test/rudra/*/*.cpp)
TESTS = $(TESTSRC:%.cpp=%)

% :	%.cpp
	

test:	$(LIB) $(TESTS)

clean:
	-$(RM) $(RUDRA_LIB_OBJS)
	-@echo ' '

.PHONY: all clean
.SECONDARY:
