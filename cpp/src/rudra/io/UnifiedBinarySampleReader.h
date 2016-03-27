/*
 * UnifiedBinarySampleReader.h
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

#ifndef UNIFIEDBINARYSAMPLEREADER_H_
#define UNIFIEDBINARYSAMPLEREADER_H_

#include "rudra/io/SampleReader.h"
#include "rudra/util/RudraRand.h"
#include <string>
#include <vector>

namespace rudra {
enum BinFileType {
	CHAR, INT, FLOAT, INVALID
};
class UnifiedBinarySampleReader: public SampleReader {
public:
	std::string trainingDataFile;
	std::string trainingLabelFile;
	BinFileType trainingDataFileType;
	BinFileType trainingLabelFileType;

	UnifiedBinarySampleReader(std::string sampleFileName,
			std::string labelFileName, RudraRand rand);
	~UnifiedBinarySampleReader();

	std::string getFileExt(const std::string& s);
	BinFileType lookupFileType(const std::string& s);
	void readLabelledSamples(const size_t batchSize, float* X, float* Y);

protected:
	void retrieveData(const size_t numSamples, const std::vector<size_t>& idx,
			float* X, float* Y);
private:
	RudraRand rand;

	void checkFiles(); // to check if files exist
	void initSizePerLabel();
};
} /* namespace rudra */

#endif /* UNIFIEDBINARYSAMPLEREADER_H_ */
