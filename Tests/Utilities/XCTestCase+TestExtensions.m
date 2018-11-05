//
//  XCTestCase+TestExtensions.m
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

#import "XCTestCase+TestExtensions.h"

#import "NSString+UniqueIdentifier.h"
#import <objc/runtime.h>

#pragma mark - Test environment

@implementation XCTestCase (ULTestEnvironment)

- (void)setUp
{
	// Ensure that our temporary directory for testing is empty
	NSURL *temporaryDirectoryURL = self.ul_temporaryDirectoryURL;
	
	if ([temporaryDirectoryURL checkResourceIsReachableAndReturnError: NULL]) {
		NSError *error;
		BOOL success = [[NSFileManager defaultManager] removeItemAtURL:temporaryDirectoryURL error:&error];
		
		if (!success)
			NSLog(@"Warning could not delete temporary test data: %@", error);
	}
}


#pragma mark - Temporary folders

- (NSString *)ul_temporaryDirectoryName
{
	return [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%@%@", NSStringFromClass(self.class), NSStringFromSelector(self.invocation.selector)]];
}

- (NSString *)ul_temporaryDirectory
{
	[[NSFileManager defaultManager] createDirectoryAtPath:self.ul_temporaryDirectoryName withIntermediateDirectories:YES attributes:nil error:NULL];
	return self.ul_temporaryDirectoryName;
}

- (NSURL *)ul_temporaryDirectoryURL
{
	return [NSURL fileURLWithPath: self.ul_temporaryDirectory];
}

- (NSURL *)ul_newTemporarySubdirectory
{
	NSURL *subDirectory = [self.ul_temporaryDirectoryURL URLByAppendingPathComponent: [NSString ul_newUniqueIdentifier]];
	[[NSFileManager defaultManager] createDirectoryAtURL:subDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
	
	// Ensure trailing slashes
	return [NSURL fileURLWithPath: subDirectory.path];
}

#pragma mark - Temporary filesystems

#if !TARGET_OS_IPHONE
NSString *ULTestCaseMSDOSFileSystemType = @"MS-DOS";
NSString *ULTestCaseHFSCaseInsensitiveFileSystemType = @"HFS+";
NSString *ULTestCaseHFSCaseSensitiveFileSystemType = @"Case-sensitive HFS+";

- (NSURL *)ul_newDummyFileSystemWithType:(NSString *)fsType size:(NSUInteger)megaBytes
{
	NSString *volumeId = [[NSString ul_newUniqueIdentifier] substringToIndex: 8];
	NSURL *diskImageURL = [[self ul_newTemporarySubdirectory] URLByAppendingPathComponent: [volumeId stringByAppendingPathExtension: @"dmg"]];
	NSURL *volumeURL = [NSURL fileURLWithPath: [@"/Volumes/" stringByAppendingString: volumeId]];
	
	// Create and mount non-HFS disk image
	NSTask *createTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"create", @"-size", [NSString stringWithFormat: @"%lum", megaBytes], @"-fs", fsType, @"-volname", volumeId, @"-o", diskImageURL.path]];
	[createTask waitUntilExit];
	
	NSTask *mountTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"mount", diskImageURL.path]];
	[mountTask waitUntilExit];
	
	return volumeURL;
}

- (void)ul_unmountDummyFilesystemAtURL:(NSURL *)volumeURL
{
	// Unmount temporary file system
	NSTask *unmountTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"unmount", volumeURL.path]];
	[unmountTask waitUntilExit];
}

- (BOOL)ul_isCaseSensitiveTestVolume
{
	NSNumber *isCaseSensitiveFS;
	NSURL *baseURL = [NSURL fileURLWithPath: NSTemporaryDirectory()];
	
	[baseURL getResourceValue:&isCaseSensitiveFS forKey:NSURLVolumeSupportsCaseSensitiveNamesKey error:NULL];
	return isCaseSensitiveFS.boolValue;
}


#pragma mark - Script runner

- (void)ul_runScript:(NSString *)script
{
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/bash" arguments:@[@"-c", script]];
	[task waitUntilExit];
}
#endif

@end


#pragma mark - Asynchronous testing

@implementation XCTestCase (ULAsynchronousTesting)

#pragma mark - Block waiting

- (BOOL)ul_performOperation:(void (^)(void (^completionHandler)(BOOL)))block
{
	NSParameterAssert(block);
	return [self ul_performOperations: @[block]];
}

- (BOOL)ul_performOperation:(void (^)(void (^completionHandler)(BOOL)))block andOperation:(void (^)(void (^completionHandler)(BOOL)))block2
{
	NSParameterAssert(block);
	NSParameterAssert(block2);
	return [self ul_performOperations: @[block, block2]];
}

- (BOOL)ul_performOperations:(NSArray *)blocks
{
	NSParameterAssert(blocks);
	
	__block BOOL success = YES;
	NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition: blocks.count];
	
	dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	void (^handler)(BOOL) = ^(BOOL succ) {
		[lock lock];
		success = success && succ;
		[lock unlockWithCondition: [lock condition]-1];
	};
	
	for (void (^block)(void (^completionHandler)(BOOL)) in blocks)
		dispatch_async(q, ^{ block(handler); });
	// Wait until finished
	[lock lockWhenCondition: 0];
	[lock unlock];
	
	return success;
}

- (id)ul_performOperationWithObjectHandler:(void (^)(void (^completionHandler)(id)))block
{
	NSParameterAssert(block);
	
	__block id object;
	NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition: 0];
	
	dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(q, ^{
		block(^(id obj) {
			[lock lock];
			object = obj;
			[lock unlockWithCondition: 1];
		});
	});
	
	// Wait until finished
	[lock lockWhenCondition: 1];
	[lock unlock];
	
	return object;
}


#pragma mark - Asynchronous Conditions

NSString *ULTestCaseAsynchronousConditionKey	= @"ULTestCaseAsynchronousConditionKey";
NSString *ULTestCaseAsynchronousAssertionKey	= @"ULTestCaseAsynchronousAssertionKey";

- (BOOL)ul_waitForCondition:(BOOL (^)(void))block onMainLoop:(BOOL)waitOnMainLoop otherQueues:(NSArray *)otherQueues timeout:(NSTimeInterval)timeout
{
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	
	while (!block()) {
		if (waitOnMainLoop)
			[[NSRunLoop mainRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:0.001]];
		
		for (NSOperationQueue *queue in otherQueues)
			[queue waitUntilAllOperationsAreFinished];
		
		if (([NSDate timeIntervalSinceReferenceDate] - start) > timeout) {
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)ul_waitForConditionOnMainLoop:(BOOL)waitOnMainLoop otherQueues:(NSArray *)otherQueues withTimeout:(NSTimeInterval)timeout andAssertionDescriptors:(NSArray *)descriptors
{
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	BOOL failed = YES;
	
	while (failed) {
		failed = NO;
		
		for (NSDictionary *descriptor in descriptors) {
			BOOL (^condition)(void) = descriptor[ULTestCaseAsynchronousConditionKey];
			if (!condition()) {
				failed = YES;
				break;
			}
		}
		
		if (waitOnMainLoop)
			[[NSRunLoop mainRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:0.01]];
		
		for (NSOperationQueue *queue in otherQueues)
			[queue waitUntilAllOperationsAreFinished];
		
		if (([NSDate timeIntervalSinceReferenceDate] - start) > timeout)
			break;
	}
	
	// Check assertions and print output on failure
	if (failed) {
		NSLog(@"Assertions not satisfied within %fs.", timeout);
		
		for (NSDictionary *descriptor in descriptors) {
			BOOL (^condition)(void) = descriptor[ULTestCaseAsynchronousConditionKey];
			if (!condition()) {
				void (^assertion)(void) = descriptor[ULTestCaseAsynchronousAssertionKey];
				assertion();
				break;
			}
		}
	}
		
	return !failed;
}

@end
