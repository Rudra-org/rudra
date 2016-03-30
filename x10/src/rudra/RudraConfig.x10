/**
 *
 * RudraConfig.x10
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

package rudra;

import x10.io.File;
import x10.io.FileReader;
import x10.io.EOFException;

/**
 * This class reads Rudra config files of the following format:
 * # Rudra sample config
 * {
 * # data files
 * trainData       = path/trainData.bin
 * trainLabels     = path/trainLabels.bin
 * testData        = path/testData.bin
 * testLabels      = path/testLabels.bin
 * meanFile        = path/meanFile.csv
 * layerCfgFile	   = path/layers.cnn
 * 
 * testInterval    = 1
 * checkpointInterval = 0
 * 
 * numTrainSamples = 16000
 * numTestSamples  = 2000
 * numInputDim	   = 3072
 * numClasses      = 10
 * numEpochs	   = 30
 * batchSize	   = 16
 * 
 * # learning rate schedule
 * learningSchedule = step
 * epochs          = 120,130
 * gamma           = 0.1
 * }
 */
public class RudraConfig {
/*(layerCfgFile:String,
    alpha:Float, momentum:Float) {
*/
    var trainData:String;
    var trainLabels:String;
    var numTrainSamples:UInt;

    var testData:String;
    var testLabels:String;
    var numTestSamples:UInt;

    var meanFile:String;

    var numEpochs:UInt;
    var mbSize:UInt;
    var checkpointInterval:UInt;
    var jobID:String;
    var lrMult:Rail[Float];

    /**
     * Number of minibatches per epoch.
     * Rounded up to nearest unit, so more MB may be generated than needed.
     */
    public def mbPerEpoch() {
        return ((numTrainSamples + mbSize - 1) / mbSize) as UInt;
    }

    public def maxMB() {
        return numEpochs * mbPerEpoch();
    }

    public static def readFromFile(fileName:String) : RudraConfig {
        val file = new FileReader(new File(fileName));

        val readConfig = (line:String) => {
            val idxEquals = line.indexOf("=");
            return line.substring(idxEquals+1n).trim();
        };

        val readUInt = (line:String) => {
            return Int.parseInt(readConfig(line)) as UInt;
        };
        val readFloat = (line:String) => {
            return Float.parseFloat(readConfig(line));
        };

        val config = new RudraConfig();

        var learningSchedule:String = null;
        var epochsStr:String = null;
        var gamma:Float = -1.0f;
        var beta:Float = -1.0f;

        try {
            var line:String = file.readLine().trim();
            while (true) {
                if (!line.startsWith("#")) {
                    Console.OUT.println(line);
                    if (line.startsWith("trainData")) {
                        config.trainData = readConfig(line);
                    } else if (line.startsWith("trainLabels")) {
                        config.trainLabels = readConfig(line);
                    } else if (line.startsWith("numTrainSamples")) {
                        config.numTrainSamples = readUInt(line);
                    } else if (line.startsWith("testData")) {
                        config.testData = readConfig(line);
                    } else if (line.startsWith("testLabels")) {
                        config.testLabels = readConfig(line);
                    } else if (line.startsWith("numTestSamples")) {
                        config.numTestSamples = readUInt(line);
                    } else if (line.startsWith("meanFile")) {
                        config.meanFile = readConfig(line);
                    } else if (line.startsWith("numEpochs")) {
                        config.numEpochs = readUInt(line);
                    } else if (line.startsWith("batchSize")) {
                        config.mbSize = readUInt(line);
                    } else if (line.startsWith("checkpointInterval")) {
                        config.checkpointInterval = readUInt(line);
                    } else if (line.startsWith("learningSchedule")) {
                        learningSchedule = readConfig(line);
                    } else if (line.startsWith("epochs")) {
                        epochsStr = readConfig(line);
                    } else if (line.startsWith("gamma")) {
                        gamma = readFloat(line);
                    } else if (line.startsWith("beta")) {
                        beta = readFloat(line);
                    }
                }
                line = file.readLine().trim();
            }
        } catch(eof:EOFException) {

        }

        if (config.numEpochs == 0un) {
            throw new Exception("Config missing: numEpochs");
        }

        val lrMult = new Rail[Float](config.numEpochs);
        if (learningSchedule == null) {
            throw new Exception("Config missing: learning schedule [contant|exponential|power|step]");
        } else if (learningSchedule.equals("exponential")) {
            if (gamma <= 0.0f) {
                throw new Exception("Config missing: gamma (must be greater than 0.0)");
            }
            lrMult(0) = 1.0f;
            for (i in 1..(config.numEpochs-1)) {
                lrMult(i) = lrMult(i-1) * gamma;
            }
        } else if (learningSchedule.equals("power")) {
            if (gamma <= 0.0f) {
                throw new Exception("Config missing: gamma (must be greater than 0.0)");
            }
            if (beta <= 0.0f) {
                throw new Exception("Config missing: beta (must be greater than 0.0)");
            }
            for (i in 0..(config.numEpochs-1)) {
                lrMult(i) = 1.0f / Math.pow(1.0f+i*gamma, beta);
            }
        } else if (learningSchedule.equals("step")) {
            if (epochsStr == null) {
                throw new Exception("Config missing: epochs");
            }
            val stepEpochs = epochsStr.split(",");
            Console.OUT.println("stepEpochs = " + stepEpochs);
            var mul:Float = 1.0f;
            for (i in 0..(config.numEpochs-1)) {
                for (step in stepEpochs) {
                    if (i == Long.parseLong(step)) {
                        mul *= gamma;
                        break;
                    }
                }
                lrMult(i) = mul;
            }
        } else {
            // assume constant learning rate schedule
            lrMult.fill(1.0f);
        }
        config.lrMult = lrMult;

        return config;
    }
}
