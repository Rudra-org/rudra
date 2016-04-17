/*
 * SampleReader.h
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

#ifndef RUDRA_IO_SAMPLEREADER_H_
#define RUDRA_IO_SAMPLEREADER_H_

#include <cstdlib>
#include <stdint.h>
#include <iostream>
#include <fstream>
#include <string>
#include <endian.h>
#include <vector>

namespace rudra {
class SampleReader {
public:
	size_t numSamples;
	size_t sizePerSample;
	size_t sizePerLabel;

	SampleReader() {
	}
	virtual ~SampleReader() {}

	virtual void readLabelledSamples(const std::vector<size_t>& idx, float* X,
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
