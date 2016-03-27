/*
 * NativeLearner.h
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

#ifndef __NATIVE_LEARNER_IMPL_H
#define __NATIVE_LEARNER_IMPL_H

#include <cstdlib>
#include <cstddef>
#include <string>

namespace rudra {
class NativeLearnerImpl;

class NativeLearner {

public:
	NativeLearner(long id);
	void cleanup(); // X10 native integration can't call C++ destructors

	// static methods section. These methods are called from static
	// Learner.initNativeLearnerStatics, once in each place.

	/** Set the working directory, for various files to be written out, e.g. weightsFile.*/
	static void setLoggingLevel(int level);
	static void setMeanFile(std::string _fileName);
	static void setAdaDeltaParams(float rho, float epsilon, float drho,
			float depsilon);
	static void setSeed(long id, int seed, int defaultSeed);
	static void setMoM(float f);
	static void setJobID(std::string jobID);
	static void initFromCFGFile(std::string confName);
	// end of static methods

	void initAsLearner(std::string trainData, std::string trainLabels,
			size_t batchSize, std::string weightsFile, std::string solverType);
	void initAsTester(long placeID, std::string solverType);

	int getNetworkSize();

    /**
     * Train the network with a minibatch of samples, storing the gradients
     * for later use and returning the training error [0.0-1.0]. Does not
     * actually update the weights; the update will be performed by a later
     * call to acceptGradients.
     */
	float trainMiniBatch();

	/**
	 * Copy the most recent set of computed gradients into the array provided.
	 * The gradients array must be of size >= [getNetworkSize()].
	 */
	void getGradients(float *gradients);

	/**
	 * Sum the most recent set of computed gradients into the array provided.
	 * The gradients array must be of size >= [getNetworkSize()], and may
	 * contain previously computed gradients.
	 */
	void accumulateGradients(float *gradients);

	/**
     * Output the current weights into the specified file.
     *
	 * @param outputFileName name of the file into which to write the weights
	 */
	void checkpoint(std::string outputFileName);

	/**
	 * Copy the current set of weights into the array provided.
	 * The weights array must be of size >= [getNetworkSize()].
	 */
	void serializeWeights(float *weights);

	/**
	 * Replace this learner's weights with the weights provided.
	 * The weights array must be of size >= [getNetworkSize()].
	 */
	void deserializeWeights(float *weights);

	/**
	 * Set the learning rate multipler used in the learner.  A lrMultipler of
	 * 1.0 means that the learning rate alpha should be the default alpha
	 * that was specified.  A lower value for lrMultiplier will reduce the
	 * learning rate accordingly.
	 * The schedule for learning rate multipliers is set by Rudra using the
	 * config file values [learningSchedule, gamma, beta, epochs].
	 * @param lrMultiplier the learning rate multiplier
	 */
	void setLearningRateMultiplier(float lrMultiplier);

	/**
	 * Update the network weights by applying the update rule with
	 * the given set of gradients.
	 * @param gradients the gradients
	 * @param multiplier amount by which to pre-multiply the gradients
	 *   before using them to update the weights, for example, to discount
	 *   gradients summed from multiple minibatches, or stale gradients
	 */
	void acceptGradients(float *gradients, const float multiplier);

	/**
	 * Initialize the network with the given weights, score your fraction
	 * of the test data, and return the proportion of test errors.
     * @param weights a set of weights for the network to perform inference
     * @param numTesters the total number of testing processes
     * @param myIndex the index of this process in the set of testing processes
     * @return the proportion of test errors, in the range [0.0,1.0]
	 */
	float testOneEpochSC(float *weights, size_t numTesters, size_t myIndex);

private:
    NativeLearnerImpl* pimpl_;
	long pid;
};
} // namespace rudra
#endif
