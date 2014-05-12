//
//  XCTestCase+TestExtensions.m
//
//  Copyright (c) 2014 The Soulmen GbR
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

#import <objc/runtime.h>


#pragma mark - Test environment

@implementation XCTestCase (TestEnvironment)

- (void)setUp
{
	// Ensure that our temporary directory for testing is empty
	NSURL *temporaryDirectoryURL = self.temporaryDirectoryURL;
	
	if ([temporaryDirectoryURL checkResourceIsReachableAndReturnError: NULL]) {
		NSError *error;
		BOOL success = [[NSFileManager defaultManager] removeItemAtURL:temporaryDirectoryURL error:&error];
		
		if (!success)
			NSLog(@"Warning could not delete temporary test data: %@", error);
	}
}


#pragma mark - Test bundles

- (NSURL *)URLForFile:(NSString *)path
{
	return [NSBundle.mainBundle URLForResource:[[path lastPathComponent] stringByDeletingPathExtension] withExtension:[path pathExtension] subdirectory:[@"Test Data" stringByAppendingPathComponent: [path stringByDeletingLastPathComponent]]];
}

- (NSFileWrapper *)fileWrapperForFile:(NSString *)path
{
	return [[NSFileWrapper alloc] initWithURL:[self URLForFile: path] options:0 error:NULL];
}


#pragma mark - Temporary folders

- (NSString *)temporaryDirectoryName
{
	return [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%@%@", NSStringFromClass(self.class), NSStringFromSelector(self.invocation.selector)]];
}

- (NSString *)temporaryDirectory
{
	[[NSFileManager defaultManager] createDirectoryAtPath:self.temporaryDirectoryName withIntermediateDirectories:YES attributes:nil error:NULL];
	return self.temporaryDirectoryName;
}

- (NSURL *)temporaryDirectoryURL
{
	return [NSURL fileURLWithPath: self.temporaryDirectory];
}

- (NSURL *)newTemporarySubdirectory
{
	NSURL *subDirectory = [self.temporaryDirectoryURL URLByAppendingPathComponent: [self.class newUniqueIdentifier]];
	[[NSFileManager defaultManager] createDirectoryAtURL:subDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
	
	// Ensure trailing slashes
	return [NSURL fileURLWithPath: subDirectory.path];
}

+ (NSString *)newUniqueIdentifier
{
	// Pure UUID
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
	CFRelease(uuid);
	
	// Remove dashes and make lowercase
	uuidString = [uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""];
	uuidString = uuidString.lowercaseString;
	
	return uuidString;
}


#pragma mark - Temporary filesystems

#if !TARGET_OS_IPHONE
NSString *TestCaseMSDOSFileSystemType = @"MS-DOS";
NSString *TestCaseHFSCaseInsensitiveFileSystemType = @"HFS+";
NSString *TestCaseHFSCaseSensitiveFileSystemType = @"Case-sensitive HFS+";

- (NSURL *)newDummyFileSystemWithType:(NSString *)fsType size:(NSUInteger)megaBytes
{
	NSString *volumeId = [[self.class newUniqueIdentifier] substringToIndex: 8];
	NSURL *diskImageURL = [[self newTemporarySubdirectory] URLByAppendingPathComponent: [volumeId stringByAppendingPathExtension: @"dmg"]];
	NSURL *volumeURL = [NSURL fileURLWithPath: [@"/Volumes/" stringByAppendingString: volumeId]];
	
	// Create and mount non-HFS disk image
	NSTask *createTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"create", @"-size", [NSString stringWithFormat: @"%lum", megaBytes], @"-fs", fsType, @"-volname", volumeId, @"-o", diskImageURL.path]];
	[createTask waitUntilExit];
	
	NSTask *mountTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"mount", diskImageURL.path]];
	[mountTask waitUntilExit];
	
	return volumeURL;
}

- (void)unmountDummyFilesystemAtURL:(NSURL *)volumeURL
{
	// Unmount temporary file system
	NSTask *unmountTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[@"unmount", volumeURL.path]];
	[unmountTask waitUntilExit];
}

- (BOOL)isCaseSensitiveTestVolume
{
	NSNumber *isCaseSensitiveFS;
	NSURL *baseURL = [NSURL fileURLWithPath: NSTemporaryDirectory()];
	
	[baseURL getResourceValue:&isCaseSensitiveFS forKey:NSURLVolumeSupportsCaseSensitiveNamesKey error:NULL];
	return isCaseSensitiveFS.boolValue;
}


#pragma mark - Script runner

- (void)runScript:(NSString *)script
{
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/bash" arguments:@[@"-c", script]];
	[task waitUntilExit];
}
#endif

@end


#pragma mark - Asynchronous testing

@implementation XCTestCase (AsynchronousTesting)

#pragma mark - Block waiting

- (BOOL)performOperation:(void (^)(void (^completionHandler)(BOOL)))block
{
	NSParameterAssert(block);
	return [self performOperations: @[block]];
}

- (BOOL)performOperation:(void (^)(void (^completionHandler)(BOOL)))block andOperation:(void (^)(void (^completionHandler)(BOOL)))block2
{
	NSParameterAssert(block);
	NSParameterAssert(block2);
	return [self performOperations: @[block, block2]];
}

- (BOOL)performOperations:(NSArray *)blocks
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

- (id)performOperationWithObjectHandler:(void (^)(void (^completionHandler)(id)))block
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

NSString *TestCaseAsynchronousConditionKey	= @"TestCaseAsynchronousConditionKey";
NSString *TestCaseAsynchronousAssertionKey	= @"TestCaseAsynchronousAssertionKey";

- (BOOL)waitForCondition:(BOOL (^)(void))block onMainLoop:(BOOL)waitOnMainLoop otherQueues:(NSArray *)otherQueues timeout:(NSTimeInterval)timeout
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

- (BOOL)waitOnMainLoop:(int)waitOnMainLoop otherQueues:(NSArray *)otherQueues withTimeout:(NSTimeInterval)timeout andAssertionDescriptors:(NSArray *)descriptors
{
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	BOOL failed = YES;
	
	while (failed) {
		failed = NO;
		
		for (NSDictionary *descriptor in descriptors) {
			BOOL (^condition)() = descriptor[TestCaseAsynchronousConditionKey];
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
			BOOL (^condition)() = descriptor[TestCaseAsynchronousConditionKey];
			if (!condition()) {
				void (^assertion)() = descriptor[TestCaseAsynchronousAssertionKey];
				assertion();
				break;
			}
		}
	}
		
	return !failed;
}

@end
