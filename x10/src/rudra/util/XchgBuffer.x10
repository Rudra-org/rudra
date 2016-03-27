/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

import x10.util.concurrent.AtomicReference;
import x10.compiler.Pinned;

/**
   A very specialized non-blocking one-place swapping buffer which communicates 
   values of type T between a producer and a consumer without consing any new 
   values or copying values. Used to couple producers and consumers that operate
   at different rates. Puts and gets are the  same operation -- an exchange!

   @author vj
 */
@Pinned public class XchgBuffer[T]{T isref}  extends SwapBuffer[T] {
    protected val datum:AtomicReference[T];
    public def this(v:T){
        datum = AtomicReference.newAtomicReference[T](v);
    }

    public def needsData():Boolean=true;
    public def xchg(t:T):T= datum.getAndSet(t);
    public def get(t:T):T= xchg(t);
    public def put(t:T):T= xchg(t);

    public def toString()="<" + typeName() + " #"+hashCode()  + ">";
}
