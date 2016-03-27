/*
 * SampleReader.h
 *
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

#ifndef RUDRA_IO_SAMPLEREADER_H_
#define RUDRA_IO_SAMPLEREADER_H_

#include <cstdlib>
#include <stdint.h>
#include <iostream>
#include <fstream>
#include <string>
#include <endian.h>

namespace rudra {
class SampleReader {
public:
	size_t numSamples;
	size_t sizePerSample;
	size_t sizePerLabel;

	SampleReader() {
	}

	virtual void readLabelledSamples(const size_t batchSize, float* X,
			float* Y) = 0;

	/**
	 * Read the number of rows and columns from the header of the given binary
	 * file.  The number of rows is stored in bytes 0-3 and the number of columns
	 * in bytes 4-7.
	 */
	static void readHeader(std::string fileName, size_t& rows, size_t& cols) {
		std::ifstream f1(fileName.c_str(), std::ios::in | std::ios::binary);
		if (!f1) {
			std::cout << "SampleReader::readHeader failed to open file: "
					<< fileName << std::endl;
			exit(EXIT_FAILURE);
		}

		int r1, c1;

		f1.read((char*) &r1, sizeof(uint32_t));	// read number of rows
		f1.read((char*) &c1, sizeof(uint32_t));	// read number of cols

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
		// swap byte order
		r1 = be32toh(r1);
		c1 = be32toh(c1);
#endif
		if (r1 < 0 || c1 < 0) {
			std::cout << "SampleReader::readHeader::Invalid matrix dimensions "
					<< r1 << "," << c1 << " in file: " << fileName << std::endl;
			exit(EXIT_FAILURE);
		}

		rows = r1;
		cols = c1;
	}
};
} // namespace rudra

#endif /* RUDRA_IO_SAMPLEREADER_H_ */
