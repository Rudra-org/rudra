/*
 * UnifiedBinarySampleReader.cpp
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#include "rudra/io/UnifiedBinarySampleReader.h"
#include "rudra/io/BinaryMatrixReader.h"
#include "rudra/util/RudraRand.h"
#include "rudra/util/Logger.h"
#include <stdint.h>
#include <algorithm>
#include <iostream>
#include <cstdlib>

namespace rudra {
UnifiedBinarySampleReader::UnifiedBinarySampleReader(std::string sampleFileName,
		std::string labelFileName, RudraRand rand) :
		trainingDataFile(sampleFileName), trainingLabelFile(labelFileName), rand(
				rand) {
	this->checkFiles();

	SampleReader::readHeader(trainingDataFile, numSamples, sizePerSample);
	size_t dummy;
	SampleReader::readHeader(trainingLabelFile, dummy, sizePerLabel);

	std::string xExt = getFileExt(trainingDataFile);
	trainingDataFileType = lookupFileType(xExt);
	std::string yExt = getFileExt(trainingLabelFile);
	trainingLabelFileType = lookupFileType(yExt);
}

UnifiedBinarySampleReader::~UnifiedBinarySampleReader() {
}

void UnifiedBinarySampleReader::checkFiles() {
	std::ifstream fx(trainingDataFile.c_str(), std::ios::in | std::ios::binary);
	if (!fx) {
		Logger::logFatal(trainingDataFile + " doesn't exist");
		exit(EXIT_FAILURE);
	}
	std::ifstream fy(trainingLabelFile.c_str(),
			std::ios::in | std::ios::binary);
	if (!fy) {
		Logger::logFatal(trainingLabelFile + " doesn't exist");
		exit(EXIT_FAILURE);
	}
}

std::string UnifiedBinarySampleReader::getFileExt(const std::string& fileName) {
	size_t i = fileName.rfind('.', fileName.length());
	if (i != std::string::npos) {
		return (fileName.substr(i + 1, fileName.length() - i));
	}

	return ("");
}

BinFileType UnifiedBinarySampleReader::lookupFileType(const std::string& s) {
	if (s.compare("bin") == 0) {
		return FLOAT;
	}
	if (s.compare("bin8") == 0) {
		return CHAR;
	}
	if (s.compare("bin32") == 0) {
		return INT;
	}
	Logger::logFatal("Wrong files extension");
	exit(EXIT_FAILURE);
}

/**
 * Read a chosen number of samples into matrix X and the corresponding labels
 * into matrix Y.
 */
void UnifiedBinarySampleReader::readLabelledSamples(const size_t batchSize,
		float* X, float* Y) {
	std::vector<size_t> idx(batchSize);
	for (size_t i = 0; i < batchSize; ++i) {
		idx[i] = rand.getLong() % numSamples;
	}
	std::sort(idx.begin(), idx.end());

	retrieveData(batchSize, idx, X, Y);
}

void UnifiedBinarySampleReader::retrieveData(const size_t batchSize,
		const std::vector<size_t>& idx, float* X, float* Y) {
	switch (trainingDataFileType) {
	case FLOAT: {
		readRecordsFromBinMat(X, batchSize, idx, sizePerSample,
				trainingDataFile);
		break;
	}

	case CHAR: {
		uint8_t* tempX = new uint8_t[batchSize * sizePerSample];
		readRecordsFromBinMat(tempX, batchSize, idx, sizePerSample,
				trainingDataFile);
		for (size_t i = 0; i < batchSize * sizePerSample; ++i) {
			X[i] = tempX[i]; // convert from uint8 to float
		}
		delete[] tempX;
		break;
	}

	case INT: {
		//TODO
		Logger::logFatal("Training data file type of INT is not supported yet");
		exit(EXIT_FAILURE);
		break;
	}
	default: {
		Logger::logFatal("Training data file type is invalid!");
		exit(EXIT_FAILURE);
		break;
	}

	}

	switch (trainingLabelFileType) {
	case FLOAT: {
		readRecordsFromBinMat(Y, batchSize, idx, sizePerLabel,
				trainingLabelFile);
		break;
	}

	case CHAR: {
		uint8_t* tempY = new uint8_t[batchSize * sizePerLabel];
		readRecordsFromBinMat(tempY, batchSize, idx, sizePerLabel,
				trainingLabelFile);
		for (size_t i = 0; i < batchSize * sizePerLabel; ++i) {
			Y[i] = tempY[i]; // convert from uint8 to float
		}
		delete[] tempY;
		break;
	}

	case INT: {
		//TODO
		Logger::logFatal(
				"Training label file type of INT is not supported yet");
		exit(EXIT_FAILURE);
		break;
	}
	default: {
		Logger::logFatal("Training label file type is invalid!");
		exit(EXIT_FAILURE);
		break;
	}

	}
}

} /* namespace rudra */
