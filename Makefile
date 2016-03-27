X10RTIMPL ?= mpi # [mpi | pami | sockets]

default: rudra-cudnn

rudra-mock:
	mkdir -p include
	mkdir -p lib
	cd cpp && make
	cd mock && make
	cd x10 && make X10RTIMPL=${X10RTIMPL} RUDRA_LEARNER=mock

# Rudra with IBM cuDNN learner.
# See https://github.rtp.raleigh.ibm.com/rudra/rudra-cudnnlearner
rudra-cudnn:
	mkdir -p include
	mkdir -p lib
	cd cpp && make
	cd x10 && make X10RTIMPL=${X10RTIMPL} RUDRA_LEARNER=cudnn

# Rudra with Theano learner.
# See https://github.com/saraswat/rudra-dist
rudra-theano:
	mkdir -p include
	mkdir -p lib
	cd cpp && make
	cd x10 && make X10RTIMPL=${X10RTIMPL} RUDRA_LEARNER=theano

# Rudra with IBM custom C++/OpenMP learner.
# See https://github.rtp.raleigh.ibm.com/rudra/rudra-learner
rudra-basic:
	mkdir -p include
	mkdir -p lib
	cd cpp && make
	cd x10 && make X10RTIMPL=${X10RTIMPL} RUDRA_LEARNER=basic

clean:
	rm -rf ./lib ./include ./rudra-mock ./rudra-cudnn ./rudra-theano ./rudra-basic lib/librudra.so cpp/librudra.so
	cd cpp && make clean
	cd x10 && make clean

.PHONY: all clean rudra-mock rudra-cudnn rudra-theano rudra-basic
