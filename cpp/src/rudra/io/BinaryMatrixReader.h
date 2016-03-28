/*
 * BinaryMatrixReader.h
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

#ifndef RUDRA_IO_BINARYMATRIXREADER_H_
#define RUDRA_IO_BINARYMATRIXREADER_H_

#include "rudra/util/MatrixContainer.h"
#include <endian.h>
#include <vector>

namespace rudra {

/** Size of a binary matrix file header. */
const size_t HEADER_SIZE = 2 * sizeof(uint32_t);

template<class T>
MatrixContainer<T> readBinMat(std::string s) {
	std::ifstream f1(s.c_str(), std::ios::in | std::ios::binary);
	if (!f1) {
		std::cout << "readBinMat: Error! failed to open file: " << s
				<< std::endl;
		exit(EXIT_FAILURE);
	}

	uint32_t rows, cols;
	f1.read((char*) &rows, sizeof(uint32_t));
	f1.read((char*) &cols, sizeof(uint32_t));
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	// swap byte order
	rows = be32toh(rows);
	cols = be32toh(cols);
#endif

	if (rows == 0 || cols == 0) {
		std::cout << "readBinMat: Invalid matrix dimensions:" << rows << " X "
				<< cols << std::endl;
		exit(EXIT_FAILURE);

	}

	MatrixContainer<T> res(rows, cols, _ZEROS);
	f1.read((char*) res.buf, rows * cols * sizeof(T));

	switch (sizeof(T)) {

	case 1:
		// no need to swap byte order
		// do nothing
		break;
	case 2:
		// 16 bit data -- need to swap byte order
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
		// swap byte order
		for (size_t i = 0; i < rows * cols; i++) {
			uint16_t swapped = be16toh(
					*reinterpret_cast<uint16_t *>(&res.buf[i]));
			res.buf[i] = *reinterpret_cast<uint16_t *>(&swapped);
		}
		break;
#endif

	case 4:
		// 32 bit data -- need to swap byte order
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
		// swap byte order
		for (size_t i = 0; i < rows * cols; i++) {
			uint32_t swapped = be32toh(
					*reinterpret_cast<uint32_t *>(&res.buf[i]));
			res.buf[i] = *reinterpret_cast<float *>(&swapped);
		}
		break;
#endif

	default:
		break;

	}
	return res;
}

/**
 * Read a single record into a matrix buffer from a binary file.
 */
template<class T>
inline void readRecordFromBinMat(T* buf, const size_t idx,
		const size_t recordSize, std::ifstream& f1) {

	size_t seekPos = HEADER_SIZE + idx * recordSize * sizeof(T);

	f1.seekg(seekPos);
	f1.read((char*) buf, recordSize * sizeof(T));

	switch (sizeof(T)) {

	case 1:
		// no need to swap byte order
		// do nothing
		break;
	case 2:
		// 16 bit data -- need to swap byte order
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
		// swap byte order
		for (size_t i = 0; i < recordSize; i++) {
			uint16_t swapped = be16toh(*reinterpret_cast<uint16_t *>(&buf[i]));
			buf[i] = *reinterpret_cast<uint16_t *>(&swapped);
		}
		break;
#endif

	case 4:
		// 32 bit data -- need to swap byte order
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
		// swap byte order
		for (size_t i = 0; i < recordSize; i++) {
			uint32_t swapped = be32toh(*reinterpret_cast<uint32_t *>(&buf[i]));
			buf[i] = *reinterpret_cast<float *>(&swapped);
		}
		break;
#endif

	default:
		break;

	}
}

/**
 * Read a single record into a matrix buffer, from a binary file with the given name.
 */
template<class T>
void readRecordFromBinMat(T* buf, const size_t idx, const size_t recordSize,
		std::string fileName) {

	std::ifstream f1(fileName.c_str(), std::ios::in | std::ios::binary);
	if (!f1) {
		std::cout << "readRecordFromBinMat: Error! failed to open file: "
				<< fileName << std::endl;
		exit(EXIT_FAILURE);
	}

	readRecordFromBinMat(buf, idx, recordSize, f1);
}

/**
 * Read a number of records from a binary file into a matrix buffer.
 * @param buf the matrix buffer into which to read the records
 * @param idx the file indices of the records to be read
 * @param recordSize the size of each record in number of fields of type T
 * @param fileName name of the binary file
 */
template<class T>
void readRecordsFromBinMat(T* buf, const std::vector<size_t> idx,
		const size_t recordSize, std::string fileName) {

	std::ifstream f1(fileName.c_str(), std::ios::in | std::ios::binary);
	if (!f1) {
		std::cout << "readRecordsFromBinMat: Error! failed to open file: "
				<< fileName << std::endl;
		exit(EXIT_FAILURE);
	}

	for (size_t i = 0; i < idx.size(); ++i) {
		readRecordFromBinMat(buf + i * recordSize, idx[i], recordSize, f1);
	}
}

}

#endif /* RUDRA_IO_BINARYMATRIXREADER_H_ */
