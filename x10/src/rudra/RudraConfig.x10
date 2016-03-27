/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
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
/*(trainData:String, trainLabels:String,
    testData:String, testLabels:String, layerCfgFile:String,
    numTestSamples:Long,
    numInputDim:Long, numClasses:Long,
    alpha:Float, momentum:Float,
    learningSchedule:String, gamma:Float, epochs:Rail[Long]) {
*/
    var trainData:String;
    var trainLabels:String;
    var numTrainSamples:UInt;
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
        if (learningSchedule.equals("exponential")) {
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
