/**
 * GPFSSampleClient.cpp
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

#include "rudra/io/GPFSSampleClient.h"
#include <cstring>
#include <pthread.h>
#include <algorithm>

namespace rudra {

GPFSSampleClient::GPFSSampleClient(std::string name, size_t batchSize,
		SampleReader* reader) :
		batchSize(batchSize), sampleReader(reader), X(
				new float[batchSize * reader->sizePerSample]), Y(
				new float[batchSize * reader->sizePerLabel]), finishedFlag(
				false), rand(), cursor(0), isRandom(false) {
	this->init();
}

GPFSSampleClient::GPFSSampleClient(std::string name, size_t batchSize,
		SampleReader* reader, RudraRand rand) :
		batchSize(batchSize), sampleReader(reader), X(
				new float[batchSize * reader->sizePerSample]), Y(
				new float[batchSize * reader->sizePerLabel]), finishedFlag(
				false), rand(rand), cursor(0), isRandom(true) {
	this->init();
}

void GPFSSampleClient::init() {
	this->count = 0;
	pthread_mutex_init(&(mutex), NULL);
	pthread_cond_init(&(fill), NULL);
	pthread_cond_init(&(empty), NULL);
	this->startProducerThd();
}

struct p_thd_args {
	GPFSSampleClient *instance;
};

void GPFSSampleClient::startProducerThd() {
	p_thd_args *pta = new p_thd_args();
	pta->instance = this;
	pthread_create(&producerTID, NULL, &(GPFSSampleClient::producerThdHook),
			pta);
}

void *GPFSSampleClient::producerThdHook(void *args) {
	p_thd_args *pargs = (p_thd_args*) args;
	pargs->instance->producerThdFunc(NULL);
	//delete pargs;// can afford this memory leak;
	return NULL;
}

void GPFSSampleClient::producerThdFunc(void *args) {
	while (!finishedFlag) {
		pthread_mutex_lock(&mutex);
		while ((count == GPFS_BUFFER_COUNT) && !finishedFlag) {
			pthread_cond_wait(&empty, &mutex);
		}
		// produce
		if (finishedFlag) {
			return;
		}

		std::vector<size_t> idx(batchSize);
		if (isRandom) {
			for (size_t i = 0; i < batchSize; ++i) {
				idx[i] = rand.getLong() % sampleReader->numSamples;
			}
			std::sort(idx.begin(), idx.end());
		} else {
			for (size_t i = 0; i < batchSize; ++i) {
				idx[i] = (cursor++) % sampleReader->numSamples;
			}
		}

		sampleReader->readLabelledSamples(idx, X, Y);
		count++; // don't forget to increment count
		pthread_cond_signal(&fill);
		pthread_mutex_unlock(&mutex);
	}

}

void GPFSSampleClient::getLabelledSamples(float* samples, float* labels) {
	pthread_mutex_lock(&mutex);
	while (count == 0) {
		pthread_cond_wait(&fill, &mutex);
	}
	memcpy(samples, X, batchSize * sampleReader->sizePerSample * sizeof(float));
	memcpy(labels, Y, batchSize * sampleReader->sizePerLabel * sizeof(float));

	count--; // don't forget the decrement count
	pthread_cond_signal(&empty);
	pthread_mutex_unlock(&mutex);
}

size_t GPFSSampleClient::getSizePerSample() {
	return sampleReader->sizePerSample;
}

size_t GPFSSampleClient::getSizePerLabel() {
	return sampleReader->sizePerLabel;
}

GPFSSampleClient::~GPFSSampleClient() {
	pthread_mutex_lock(&mutex);
	finishedFlag = true;
	pthread_cond_signal(&empty);
	pthread_mutex_unlock(&mutex);
	pthread_join(producerTID, NULL); // join the producer thread
	delete[] X;
	delete[] Y;
}
} /* namespace rudra */
