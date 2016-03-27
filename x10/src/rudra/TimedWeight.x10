/**
 *
 * TimedWeight.x10
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

/** TimedWeight is the same as TimedGradient except that the payload rail is of networkSize
    rather than networkSize+1. It represents a time stamped set of weights for the NN, together
    with  loadSize that represents the number of MB used to compute this weight.
    @author vj
 */
public class TimedWeight(size:Long) implements TimedWeightI { // mutated in place, hence fields are vars.
    public static val POISON=new TimedWeight(0,0un);
    var timeStamp:UInt=0un;
    var loadSize:UInt=0un;
    var weight:Rail[Float] = new Rail[Float](size);
    def this(size:Long){property(size);}
    def this(size:Long, ls:UInt){property(size); loadSize=ls;}

    public def loadSize():UInt=loadSize;
    public def setLoadSize(l:UInt):void{
        loadSize=l;
    }
    public def weightRail() = weight;
    public def timeStamp() = timeStamp;
    public def setTimeStamp(t:UInt):void {
        timeStamp = t;

}
    def calcHash():Float = calcHash(weight);
    public static def calcHash(f:Rail[Float]):Float {
        var result:Float=0.0f;
        for (x in f) result+=x;
        return result/f.size;
    }
    public def toString():String = "<TW #" + hashCode() + " load="+ calcHash()
                          +",size="+ loadSize + ",time="+timeStamp+">";
}
