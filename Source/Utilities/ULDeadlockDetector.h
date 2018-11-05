//
//  ULDeadlockDetector.h
//
//  Copyright © 2018 Ulysses GmbH & Co. KG
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

@protocol ULDeadlockDetectorDelegate;

typedef void (^ULDeadlockDetectorOperationBlock)(void (^completionHandler)(void));

/*!
 @abstract Performs an (asynchronous) task and detects whether it exceeds a certain time limit.
 */
@interface ULDeadlockDetector : NSObject

/*!
 @abstract Performs a block with a certain limit on its execution duration.
 @discussion Calls the passed delegate if the operation did not call the passed completion handler within the given time limit. The detector instance stays alive until the completion handler has been disposed. The given context is specific to the delegate.
 */
+ (instancetype)performOperationWithContext:(id)context maximumDuration:(NSTimeInterval)maximumDuration delegate:(id<ULDeadlockDetectorDelegate>)delegate usingBlock:(ULDeadlockDetectorOperationBlock)block;

/*!
 @abstract A delegate-specific context identifying the deadlock detector.
 */
@property(nonatomic, readonly) id context;

@end

@protocol ULDeadlockDetectorDelegate <NSObject>

/*!
 @abstract Notifies the delegate that an operation exceeded its time limit.
 */
- (void)deadlockDetectorDidExceedTimeLimit:(ULDeadlockDetector *)deadlockDetector;

@end
