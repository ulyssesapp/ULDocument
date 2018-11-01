//
//  ULDeadlockDetector.h
//  Ulysses
//
//  Created by Friedrich Gräter on 05/01/16.
//  Copyright © 2016 The Soulmen. All rights reserved.
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
