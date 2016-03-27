/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

import x10.io.Unserializable;

/**
   A very specialized non-blocking one-place swapping buffer which communicates 
   values of type T between a producer and a consumer without consing any new 
   values or copying values. Used to couple producers and consumers that operate
   at different rates. 
   @author vj
 */
public abstract class SwapBuffer[T]{T haszero} implements Unserializable {

    public static def make[T](t:T){T haszero}:SwapBuffer[T]=make[T](true, t);
    public static def make[T](nb:Boolean, t:T){T haszero}:SwapBuffer[T] 
        = nb? new NBSwapBuffer[T](t): new BlockingSwapBuffer[T](t);

    /** Buffer can accept a put request without blocking.
     */
    public abstract def needsData():Boolean;
    /** In nonblocking mode, returns the result of swapping datum with t (if datum is available),
        else t.
        In blocking mode, waits until datum is available then returns result of swapping it with t.
     */
    public abstract def get(t:T):T;

    /** In nonblocking mode, returns the result of swapping datum with t (if datum is unavailable),
        else t.
        In blocking mode, waits until datum is unavailable then returns result of swapping it with t.
     */
    public abstract def put(t:T):T;

}
