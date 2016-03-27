/**
 * GPFSSampleClient.cpp
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#include "rudra/io/GPFSSampleClient.h"
#include <cstring>
#include <pthread.h>

namespace rudra {
GPFSSampleClient::GPFSSampleClient(std::string name, size_t batchSize,
		bool threaded, SampleReader* reader) :
		batchSize(batchSize), threaded(threaded), sampleReader(reader), X(
				new float[batchSize * reader->sizePerSample]), Y(
				new float[batchSize * reader->sizePerLabel]), finishedFlag(
				false) {
	this->init();
}

void GPFSSampleClient::init() {
	this->count = 0;
	if (threaded) {
		pthread_mutex_init(&(mutex), NULL);
		pthread_cond_init(&(fill), NULL);
		pthread_cond_init(&(empty), NULL);
		this->startProducerThd();
	}

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
		sampleReader->readLabelledSamples(batchSize, X, Y);
		count++; // don't forget to increment count
		pthread_cond_signal(&fill);
		pthread_mutex_unlock(&mutex);
	}

}

void GPFSSampleClient::getLabelledSamples(float* samples, float* labels) {
	if (threaded) {
		pthread_mutex_lock(&mutex);
		while (count == 0) {
			pthread_cond_wait(&fill, &mutex);
		}
		memcpy(samples, X,
				batchSize * sampleReader->sizePerSample * sizeof(float));
		memcpy(labels, Y,
				batchSize * sampleReader->sizePerLabel * sizeof(float));

		count--; // don't forget the decrement count
		pthread_cond_signal(&empty);
		pthread_mutex_unlock(&mutex);
	} else {
		sampleReader->readLabelledSamples(batchSize, samples, labels);
	}
}

size_t GPFSSampleClient::getSizePerSample() {
	return sampleReader->sizePerSample;
}

size_t GPFSSampleClient::getSizePerLabel() {
	return sampleReader->sizePerLabel;
}

GPFSSampleClient::~GPFSSampleClient() {
	if (threaded) {
		pthread_mutex_lock(&mutex);
		finishedFlag = true;
		pthread_cond_signal(&empty);
		pthread_mutex_unlock(&mutex);
		pthread_join(producerTID, NULL); // join the producer thread
	}
	delete[] X;
	delete[] Y;
}
} /* namespace rudra */
