/*
 * RudraRand.cpp
 *
 * Rudra Distributed Learning Platform
 *
 * Copyright (c) IBM Corporation 2016
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * 3. Neither the name of Rudra nor the names of its contributors may be used
 *   to endorse or promote products derived from this software without specific
 *   prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "rudra/util/RudraRand.h"
#include <sys/time.h>
#include <iostream>
namespace rudra {
RudraRand::RudraRand(int rank, int threadid) :
		rank(rank), threadid(threadid) {
	struct timeval start;
	gettimeofday(&start, NULL);

	unsigned int seed = (unsigned int) ((float) start.tv_usec
			/ (float) ((rank + 1) * (rank + 1)));
	srand48_r(seed, &dd);
}

RudraRand::RudraRand(const RudraRand& rr) {
	this->rank = rr.rank;
	this->threadid = rr.threadid;
	struct timeval start;
	gettimeofday(&start, NULL);

	unsigned int seed = (unsigned int) ((float) start.tv_usec
			/ (float) ((rank + 1) * (rank + 1)));
	srand48_r(seed, &dd);
}

long RudraRand::getLong() {
	long result;
	lrand48_r(&dd, &result);
	return result;
}

RudraRand::~RudraRand() {
}

} /*namespace rudra*/
