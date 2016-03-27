/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

public interface TimedWeightI {

    def loadSize():UInt;
    def setLoadSize(u:UInt):void;
    def timeStamp():UInt;
    def setTimeStamp(u:UInt):void;

    def weightRail():Rail[Float];
}
