/*
 * UnifiedBinarySampleSeqReader.cpp
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#include "rudra/io/UnifiedBinarySampleSeqReader.h"
#include <vector>

namespace rudra {
UnifiedBinarySampleSeqReader::UnifiedBinarySampleSeqReader(
		std::string sampleFileName, std::string labelFileName) :
		UnifiedBinarySampleReader(sampleFileName, labelFileName, RudraRand()), cursor(
				0) {

}

UnifiedBinarySampleSeqReader::UnifiedBinarySampleSeqReader(
		std::string sampleFileName, std::string labelFileName, size_t cursor) :
		UnifiedBinarySampleReader(sampleFileName, labelFileName, RudraRand()), cursor(
				cursor) {

}

UnifiedBinarySampleSeqReader::~UnifiedBinarySampleSeqReader() {
}

/**
 * Read a batch of the given size into buffer X and the corresponding labels
 * into buffer Y.
 */
void UnifiedBinarySampleSeqReader::readLabelledSamples(const size_t batchSize,
		float* X, float* Y) {

	// prepare the indices that we need to retrieve
	std::vector<size_t> idx(batchSize);
	for (size_t i = 0; i < batchSize; ++i) {
		idx[i] = (cursor++) % numSamples;
	}
	retrieveData(batchSize, idx, X, Y);
}

} /* namespace rudra */
