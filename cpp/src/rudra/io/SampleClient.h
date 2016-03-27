/*
 * SampleClient.h
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#ifndef RUDRA_SAMPLE_SAMPLECLIENT_H_
#define RUDRA_SAMPLE_SAMPLECLIENT_H_

#include <cstddef>

namespace rudra {

class SampleClient {
public:
	virtual size_t getSizePerLabel() = 0;
	virtual void getLabelledSamples(float* samples, float* labels) = 0;
};
} /* namespace rudra */

#endif /* RUDRA_SAMPLE_SAMPLECLIENT_H_ */
