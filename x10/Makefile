# ==== START CONFIGURATION ====

# All of these parameters may be set on the command line or in this file.

# Full path to x10c++ if not in $PATH
X10CXX_BIN ?= x10c++

# Set to 1 to enable profiling
PROFILE ?=

# ===== END CONFIGURATION =====

arch=$(shell uname -p)
ifeq ($(arch),unknown)
    arch=$(shell uname -m)
endif

X10FLAG = -O -g -NO_CHECKS -VERBOSE_CHECKS -report postcompile=1

ifeq ($(arch),ppc64)
    # POWER7 (inc. p775)
	CXX = xlC_r
    BLASLIB ?= ESSL
    X10RTIMPL ?= pami
else
    X10CXX_PREARGS += -cxx-prearg -std=c++0x
    X10RTIMPL ?= mpi
endif

ifdef X10RTIMPL # sockets, mpi, pami, etc.
  X10FLAG += -x10rt ${X10RTIMPL}
endif

# enable CPU profiling with google-perftools
ifdef PROFILE
  X10CXX_PREARGS += -gpt
endif

RUDRA_LEARNER ?= theano
RUDRA_EXE = rudra-$(RUDRA_LEARNER)

X10CXX_PREARGS += -cxx-prearg -I$(RUDRA_HOME)/include
X10CXX_POSTARGS += -cxx-postarg -L$(RUDRA_HOME)/lib -cxx-postarg -lrudra -cxx-postarg -lrudralearner-$(RUDRA_LEARNER)

# vj need to add these for theano linkage.
# TODO: Do this in a system generic way, this is obtained by
# by splicing -cxx-postarg in between the terms returned by python2.7-config --ldflags
# and quoting
ifeq ($(RUDRA_LEARNER),theano)
    X10CXX_POSTARGS += -cxx-postarg -L/usr/lib/python2.7/config-x86_64-linux-gnu -cxx-postarg -L/usr/lib64 -cxx-postarg -lpthread -cxx-postarg -ldl  -cxx-postarg -lutil -cxx-postarg -lm  -cxx-postarg -lpython2.7 -cxx-postarg -Xlinker -cxx-postarg -export-dynamic -cxx-postarg "-Wl,-O1" -cxx-postarg "-Wl,-Bsymbolic-functions"
else
    ifeq ($(RUDRA_LEARNER),cudnn)
            X10CXX_POSTARGS += -cxx-postarg -L$(CUDA_LIB) -cxx-postarg -L$(CUDNN_PATH)/lib64 -cxx-postarg -lcudnn -cxx-postarg -lcudart -cxx-postarg -lcudadevrt -cxx-postarg -lcublas
    endif
endif

all: rudra
rudra: src/rudra/Rudra.x10 src/rudra/Learner.x10 src/rudra/Tester.x10 src/rudra/TestManager.x10 src/rudra/ImmedLearner.x10 src/rudra/ImmedReconciler.x10 src/rudra/ApplyLearner.x10 src/rudra/ApplyReconciler.x10 src/rudra/HardSync.x10 src/rudra/AtLeastRAllReducer.x10 src/rudra/NativeLearner.x10 src/rudra/util/*SwapBuffer.x10 src/rudra/util/Timer.x10 src/rudra/util/Logger.x10 
	x10c++ $(X10FLAG) -sourcepath src $(X10_POST) $(X10CXX_PREARGS) $(X10CXX_POSTARGS) -d ./tmp src/rudra/Rudra.x10 -o $(RUDRA_HOME)/$(RUDRA_EXE)

clean:
	$(RM) -fr ./tmp
