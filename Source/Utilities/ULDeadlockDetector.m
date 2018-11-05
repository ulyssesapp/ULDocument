//
//  ULDeadlockDetector.m
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
