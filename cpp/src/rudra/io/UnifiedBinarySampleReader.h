/*
 * UnifiedBinarySampleReader.h
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
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
