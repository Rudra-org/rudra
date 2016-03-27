/**
 * GPFSSampleClient.h
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#ifndef RUDRA_IO_GPFSSAMPLECLIENT_H
#define RUDRA_IO_GPFSSAMPLECLIENT_H

#include "rudra/io/SampleReader.h"
#include "rudra/io/SampleClient.h"
#include <iostream>
#include <pthread.h>

#define GPFS_BUFFER_COUNT 1

namespace rudra {
class GPFSSampleClient: public SampleClient {
public:
	const size_t batchSize;

	GPFSSampleClient(std::string name, size_t batchSize, bool threaded,
			SampleReader *sampleReader);
	//@Override
	void getLabelledSamples(float* samples, float* labels);
	size_t getSizePerSample();
	size_t getSizePerLabel();
	~GPFSSampleClient();
protected:
	void producerThdFunc(void *args);
private:
	bool threaded;
	SampleReader *sampleReader;
	float* X; // training data minibatch
	float* Y; // training label minibatch
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
