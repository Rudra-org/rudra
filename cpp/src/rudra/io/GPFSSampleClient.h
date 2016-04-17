/**
 * GPFSSampleClient.h
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

#ifndef RUDRA_IO_GPFSSAMPLECLIENT_H
#define RUDRA_IO_GPFSSAMPLECLIENT_H

#include "rudra/io/SampleClient.h"
#include "rudra/util/RudraRand.h"
#include <iostream>
#include <pthread.h>

#define GPFS_BUFFER_COUNT 1

namespace rudra {
class SampleReader;

class GPFSSampleClient: public SampleClient {
public:
	const size_t batchSize;

	/** Construct a new GPFSSampleClient to read samples in order. */
	GPFSSampleClient(std::string name, size_t batchSize,
			SampleReader *sampleReader);

	/** Construct a new GPFSSampleClient to read random samples. */
	GPFSSampleClient(std::string name, size_t batchSize,
			SampleReader *sampleReader, RudraRand rand);

	//@Override
	void getLabelledSamples(float* samples, float* labels);
	size_t getSizePerSample();
	size_t getSizePerLabel();
	~GPFSSampleClient();
protected:
	void producerThdFunc(void *args);
private:
	SampleReader *sampleReader;
	float* X; // training data minibatch
	float* Y; // training label minibatch
	const bool isRandom;
	RudraRand rand; // PRNG for random sampling
	size_t cursor; // file cursor for sequential sampling
	volatile bool finishedFlag;
	volatile int count;
	pthread_cond_t empty;
	pthread_cond_t fill;
	pthread_mutex_t mutex;
	pthread_t producerTID; //producer thread id
	void startProducerThd();
	static void* producerThdHook(void *args);
	void init();
};
}
#endif /* RUDRA_IO_GPFSSAMPLECLIENT_H */
