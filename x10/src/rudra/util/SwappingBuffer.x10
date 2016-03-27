/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

import x10.compiler.Volatile;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.compiler.Pinned;
import x10.io.Unserializable;

/**
   A very specialized non-blocking one-place swapping buffer which communicates 
   values of type T between a producer and a consumer without consing any new 
   values or copying values. Used to couple producers and consumers that operate
   at different rates. 
   @author vj
 */
@Pinned public class SwappingBuffer[T]{T haszero} implements Unserializable {
    @Volatile protected var datum:T;
    public def this(i:T){
	this.datum=i;
    }

    /** Set by the writer, when the data is ready to be read from index+1. 
     * Reset by the reader when it reads the data.
     */
    protected val dataReady=new AtomicBoolean(false);

    /** Non-blocking call. If no value is available to read return t 
	(the caller should think that a zero value was returned).
        Otherwise return the available value (guaranteed to not 
	equal t), and signal that data is needed. 
     */
    public def get(t:T):T{
	if (!dataReady.get()) return t;
	val result=datum;
	assert t!=result;
	datum=t;
	dataReady.set(false);
	return result;
    }

    /** Non-blocking call. If there is no space return t with no modifications; 
	the caller may continue to use t. Else add t to the buffer signal 
        that data is ready, and return the old value s. Note s is not zeroed,
        it is the caller's responsibility to write application data in it
        before reading. The caller must check the return value to determine
	which of these two cases apply.
     */

    public def put(t:T):T{
	if (dataReady.get()) return t;
	val result=datum;
	assert t!=result;
	datum=t;
	dataReady.set(true);
	return result;
    }
    public def toString()="<" + typeName() + " #"+hashCode()  + ">";
}
