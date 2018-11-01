//
//  XCTestCase+TemporaryState.h
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

#import <XCTest/XCTest.h>

#pragma mark - Test environment

@interface XCTestCase (ULTestEnvironment)

/*!
 @abstract Creates a new, unique temporary subdirectory for the current test case. The directory will be destroyed when starting the test case the next time.
 */
- (NSURL *)ul_newTemporarySubdirectory;

#if !TARGET_OS_IPHONE
/*!
 @abstract Creates a temporary file system image for running a test case.
 @discussion Available file system types are TestCaseMSDOSFileSystemType, TestCaseHFSCaseInsensitiveFileSystemType, TestCaseHFSCaseSensitiveFileSystemType.
 */
- (NSURL *)ul_newDummyFileSystemWithType:(NSString *)fsType size:(NSUInteger)megaBytes;

extern NSString *ULTestCaseMSDOSFileSystemType;
extern NSString *ULTestCaseHFSCaseInsensitiveFileSystemType;
extern NSString *ULTestCaseHFSCaseSensitiveFileSystemType;

/*!
 @abstract Unmounts a temporary test file system.
 */
- (void)ul_unmountDummyFilesystemAtURL:(NSURL *)volumeURL;

/*!
 @abstract Verifies whether the tests are running on a case sensitive volume.
 */
- (BOOL)ul_isCaseSensitiveTestVolume;

/*!
 @abstract Runs the passed command line script and waits for its termination.
 */
- (void)ul_runScript:(NSString *)script;
#endif

@end


#pragma mark - Assertion convenience

#define ULAssertEqualRange(__rangeA, __rangeB, __description, __other...)				{\
		NSRange __rangeAValue = (__rangeA);\
		NSRange __rangeBValue = (__rangeB);\
		\
		XCTAssertTrue(NSEqualRanges(__rangeAValue, __rangeBValue), __description, ##__other);\
	}

#define ULAssertEqualSize(__sizeA, __sizeB, __description, __other...)					{\
		CGSize __safeValueA = (__sizeA);\
		CGSize __safeValueB = (__sizeB);\
		\
		XCTAssertTrue(CGSizeEqualToSize(__safeValueA, __safeValueB), __description, ##__other);\
	}

#define ULAssertEqualRect(__rectA, __rectB, __description, __other...)					{\
		CGRect __safeValueA = (__rectA);\
		CGRect __safeValueB = (__rectB);\
		\
		XCTAssertTrue(CGRectEqualToRect(__safeValueA, __safeValueB), __description, ##__other);\
	}

#define ULAssertEqualEdgeInsets(__insetsA, __insetsB, __description, __other...)		{\
		NSEdgeInsets __safeValueA = (__insetsA);\
		NSEdgeInsets __safeValueB = (__insetsB);\
		\
		XCTAssertTrue((__safeValueA.top == __safeValueB.top && __safeValueA.left == __safeValueB.left && __safeValueA.right == __safeValueB.right && __safeValueA.bottom == __safeValueB.bottom), __description, ##__other);\
	}

#define ULAssertEqualStructs(__structA, __structB, __description, __other...)			{\
		typeof(__structA) __structValueA = __structA;\
		typeof(__structB) __structValueB = __structB;\
		\
		XCTAssertTrue([[NSValue value:&__structValueA withObjCType:@encode(typeof(__structValueA))] isEqualToValue: [NSValue value:&__structValueB withObjCType:@encode(typeof(__structValueB))]], __description, ##__other);\
	}


#pragma mark - Asynchronous testing

@interface XCTestCase (UL_AsynchronousTesting)

/*!
 @abstract Performs an operation and waits for the completion handler to be executed.
 */
- (BOOL)ul_performOperation:(void (^)(void (^completionHandler)(BOOL)))block;

/*!
 @abstract Performs two operations and waits for the completion handlers to be executed.
 */
- (BOOL)ul_performOperation:(void (^)(void (^completionHandler)(BOOL)))block andOperation:(void (^)(void (^completionHandler)(BOOL)))block2;

/*!
 @abstract Performs a series of operations. Each operation is a block with the signature void (^)(void (^completionHandler)(BOOL)). Waits for the passed completion handler to be executed.
 */
- (BOOL)ul_performOperations:(NSArray *)blocks;

/*!
 @abstract Performs an operation and waits for a completion handler to complete.
 */
- (id)ul_performOperationWithObjectHandler:(void (^)(void (^completionHandler)(id)))block;


/*!
 @abstract Returns 'YES' if the condition was satisfied within the given timeout
 */
- (BOOL)ul_waitForCondition:(BOOL (^)(void))block onMainLoop:(BOOL)waitOnMainLoop otherQueues:(NSArray *)otherQueues timeout:(NSTimeInterval)timeout;

/*
 * @abstract Waits for a series of assertions to become true in a specified timeout. If no assertion becomes true, a failure block will be performed.
 * @discussion Please use ULWaitOnAssertions or ULWaitOnAssertion! It provides better error reporting if an assertion fails! The conditions array consists of pairs of dictionaries using TestCaseAsynchronousConditionKey and TestCaseAsynchronousAssertionKey.
 */
- (BOOL)ul_waitForConditionOnMainLoop:(BOOL)waitOnMainLoop otherQueues:(NSArray *)otherQueues withTimeout:(NSTimeInterval)timeout andAssertionDescriptors:(NSArray *)descriptors;

/*!
 * @abstract A key used in assertion descriptors. Maps to a block ^BOOL() that should be used to test whether an asynchronous assertion has become true.
 */
extern NSString *ULTestCaseAsynchronousConditionKey;

/*!
 * @abstract A key used in assertion descriptors. Maps to a block ^() that should perform a XCTestFail with a descriptive error message.
 */
extern NSString *ULTestCaseAsynchronousAssertionKey;

@end

// Waits for a block of assertions (defined with ULAwaitedAssertion)
#define ULWaitOnAssertions(__args...)									([self ul_waitForConditionOnMainLoop:YES otherQueues:nil withTimeout:10 andAssertionDescriptors:@[ __args ]])

// Convenience: Waits and asserts a single condition
#define ULWaitOnAssertion(__condition, ...)								ULWaitOnAssertions(ULAwaitedAssertion(__condition, @"" __VA_ARGS__));

// Convenience: Waits and asserts that two objects are equal
#define ULWaitOnEqual(__varA, __varB, ...)								ULWaitOnAssertion((__varA) == (__varB), __VA_ARGS__);

// Convenience: Waits and asserts that two objects are equal
#define ULWaitOnEqualObjects(__objectA, __objectB, ...)					ULWaitOnAssertion([(__objectA) isEqual: (__objectB)],  __VA_ARGS__);

// An assertion that should be waited for in ULWaitOnAssertions
#define ULAwaitedAssertion(__condition, __description, __other...)		\
	@{\
		ULTestCaseAsynchronousConditionKey:		^BOOL{ return ((__condition) != 0); },\
		ULTestCaseAsynchronousAssertionKey:		^{ XCTFail(__description, ##__other); }\
	}

// Executes the given statements during the wait operation. If variables should be manipulated, these variables must be declared with __block scope.
#define ULPerformOnWait(__statements)					@{ULTestCaseAsynchronousConditionKey: ^BOOL{ __statements; return YES; }, ULTestCaseAsynchronousAssertionKey: ^{ } }

// Convenience: Asserts whether two file URLs are equal.
#define ULAssertEqualFileURLs(__urlA, __urlB, __description, __other...)				XCTAssertTrue([(__urlA) ul_isEqualToFileURL: (__urlB)], __description, ##__other)
