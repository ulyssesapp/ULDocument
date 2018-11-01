//
//  ULDeadlockDetector.m
//  Ulysses
//
//  Created by Friedrich Gräter on 05/01/16.
//  Copyright © 2016 The Soulmen. All rights reserved.
//

#import "ULDeadlockDetector.h"

@interface ULDeadlockDetector ()

@property(nonatomic, readwrite, strong) dispatch_source_t limitingTimer;

@property(nonatomic, readonly) NSTimeInterval maximumDuration;
@property(nonatomic, readonly, weak) id<ULDeadlockDetectorDelegate> delegate;
@property(nonatomic, readonly, weak) ULDeadlockDetectorOperationBlock block;

@end

@implementation ULDeadlockDetector

+ (instancetype)performOperationWithContext:(id)context maximumDuration:(NSTimeInterval)maximumDuration delegate:(id<ULDeadlockDetectorDelegate>)delegate usingBlock:(ULDeadlockDetectorOperationBlock)block;
{
	ULDeadlockDetector *detector = [[self alloc] initWithContext:context maximumDuration:maximumDuration delegate:delegate block:block];
	[detector performOperation];
	
	return detector;
}

- (instancetype)initWithContext:(id)context maximumDuration:(NSTimeInterval)maximumDuration delegate:(id<ULDeadlockDetectorDelegate>)delegate block:(void (^)(void (^)(void)))block
{
	self = [super init];
	
	if (self) {
		_context = context;
		_maximumDuration = maximumDuration;
		_delegate = delegate;
		_block = block;
	}
	
	return self;
}

- (void)performOperation
{
	// Setup limiting timer
	self.limitingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
	dispatch_source_set_timer(self.limitingTimer, dispatch_time(DISPATCH_TIME_NOW, self.maximumDuration * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1);
	
	// Notify about deadlock if timer has been reached
	dispatch_source_set_event_handler(self.limitingTimer, ^{
		[self.delegate deadlockDetectorDidExceedTimeLimit: self];
	});
	
	dispatch_resume(self.limitingTimer);
	
	// The block's completion handler
	self.block(^{
		[self cancelTimer];
	});
}

- (void)cancelTimer
{
	dispatch_cancel(self.limitingTimer);
	self.limitingTimer = nil;
}

- (void)dealloc
{
	NSAssert(!self.limitingTimer, @"Deadlock detector was deallocated without completion handler being called.");
}

@end
