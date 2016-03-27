/*
 * UnifiedBinarySampleSeqReader.cpp
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
