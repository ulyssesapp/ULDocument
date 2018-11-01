//
//  ULDocumentTest.m
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

#import "ULDocument.h"
#import "ULDocument_Subclassing.h"

#import "NSDate+Utilities.h"
#import "NSString+UniqueIdentifier.h"
#import "NSURL+PathUtilities.h"
#import "XCTestCase+TestExtensions.h"

#define dispatch_async_on_global_queue(__block)			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), (__block))
#define break_undo_coalesing()		[NSRunLoop.currentRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.0001]];

BOOL ULTestDocumentUsesConsistentPersistenceFormat		= YES;
BOOL ULTestDocumentShouldHandleSubitemChanges			= NO;

NSString *kTestText1	= @"Vivamus et turpis in dui blandit pulvinar nec dignissim diam.";
NSString *kTestText2	= @"Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.";
NSString *kTestText3	= @"Fusce tincidunt erat sit amet magna porttitor nec iaculis diam varius.";


@interface ULStubDocument : ULDocument
@end

@implementation ULStubDocument
@end

@interface ULDocument ()

- (void)presentedItemDidChange;
- (void)applicationWillTerminate:(NSNotification *)notification;

@end

@interface ULTestDocument : ULDocument

@property(nonatomic, copy) NSString *text;

@property(nonatomic, readwrite) NSUInteger writeCount;
@property(nonatomic, readwrite) dispatch_semaphore_t afterWriteLock;

@property(nonatomic, readwrite) NSString *recognizedFilenameChange;
@property(nonatomic, readwrite) NSURL *recognizedMoveURL;

@property(nonatomic, readwrite) BOOL terminationNotified;

@end

@implementation ULTestDocument

- (id)initWithFileURL:(NSURL *)url readOnly:(BOOL)readOnly
{
	self = [super initWithFileURL:url readOnly:readOnly];

	if (self) {
		_writeCount = 0;
		_terminationNotified = NO;
	}
	
	return self;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	_terminationNotified = YES;
	[super applicationWillTerminate: notification];
}

- (void)setText:(NSString *)text
{
	[self.undoManager registerUndoWithTarget:self selector:@selector(setText:) object:self.text];
	_text = [text copy];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper error:(NSError **)outError
{
	if (self.class.shouldHandleSubitemChanges) {
		self.text = [[NSString alloc] initWithData:[fileWrapper.fileWrappers[@"content.txt"] regularFileContents] encoding:NSUTF8StringEncoding];
		return YES;
	}
	
	self.text = [[NSString alloc] initWithData:fileWrapper.regularFileContents encoding:NSUTF8StringEncoding];
	return YES;
}

- (NSFileWrapper *)fileWrapperWithError:(NSError **)outError
{
	NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents: [self.text dataUsingEncoding: NSUTF8StringEncoding]];
	
	if (self.class.shouldHandleSubitemChanges) {
		NSFileWrapper *secondaryWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: [@"otherFile" dataUsingEncoding: NSUTF8StringEncoding]];
		wrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"content.txt": wrapper, @"otherFile.txt": secondaryWrapper}];
	}
	
	_writeCount ++;
	
	// Allows to inject changes immediately after writing
	if (_afterWriteLock) {
		dispatch_semaphore_wait(_afterWriteLock, DISPATCH_TIME_FOREVER);
		dispatch_semaphore_signal(_afterWriteLock);
	}
	
	return wrapper;
}

+ (BOOL)shouldHandleSubitemChanges
{
	return ULTestDocumentShouldHandleSubitemChanges;
}

- (void)didChangeFileURLBySaving
{
	_recognizedFilenameChange = self.fileURL.lastPathComponent;
}

- (void)didMoveToURL:(NSURL *)newURL
{
	_recognizedMoveURL = newURL;
}

+ (BOOL)usesConsistentPersistenceFormat
{
	return ULTestDocumentUsesConsistentPersistenceFormat;
}

@end

@interface ULDocumentTest : XCTestCase
@end

@implementation ULDocumentTest

- (void)setUp
{
	[super setUp];
	
	// By default, test document uses a consistent persistence format
	ULTestDocumentUsesConsistentPersistenceFormat = YES;
	ULTestDocumentShouldHandleSubitemChanges = NO;
	
	// Large delays while testing
	[ULDocument setAutosaveDelay: 3000];
	[ULDocument setAutoversioningInterval: 10000];
}

- (NSURL *)createTestDocument
{
	NSURL *url = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.txt", random()]];
	[kTestText1 writeToURL:url atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	return url;
}

- (void)testStatic
{
	XCTAssertThrows((void)[[ULDocument alloc] init], @"Abstract class should not instantiate");
	XCTAssertThrows((void)[ULTestDocument defaultFileType], @"Non-overridden method should raise");
	XCTAssertThrows((void)[ULTestDocument defaultPathExtension], @"Non-overridden method should raise");
	XCTAssertThrows((void)[[ULStubDocument new] fileWrapperWithError: NULL], @"Non-overridden method should raise");
	XCTAssertThrows((void)[[ULStubDocument new] readFromFileWrapper:nil error:NULL], @"Non-overridden method should raise");
}

- (void)testDocumentReading
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	XCTAssertNil(document.fileModificationDate, @"No change date should be set");
	XCTAssertNil(document.changeDate, @"No change date should be set");
	XCTAssertFalse(document.documentIsOpen, @"Document should be closed yet");
	XCTAssertFalse(document.hasUnsavedChanges, @"Closed documents must not have any changes");
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	// Check text
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertNotNil(document.fileModificationDate, @"File change date should be set");
	XCTAssertNil(document.changeDate, @"No change date should be set");
	XCTAssertTrue(document.documentIsOpen, @"Document should be open");
	XCTAssertFalse(document.hasUnsavedChanges, @"Fresh documents must not have any changes");
	
	// Close document
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document closeWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Closing failed");
}

- (void)testErrorReading
{
	NSURL *url = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.fake", random()]];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertFalse(success, @"Reading should fail");
	XCTAssertNotNil(document.lastReadError, @"Document should provide error code.");
	
	// Close document
	[document close];
}

- (void)testErrorWriting
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Reading failed");
	
	// Lock document access
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0} ofItemAtPath:url.path error:NULL];
	
	// Failing save
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveWithCompletionHandler: handler];
	}];
	XCTAssertFalse(success, @"Writing should fail");
	XCTAssertNotNil(document.lastWriteError, @"Document should provide error code.");
	
	// Close document
	[document close];
	
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0666} ofItemAtPath:url.path error:NULL];
}

- (void)testPostingErrorNotificationsOnAsynchronousWrite
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	
	// Setup observer
	__block NSNotification *notification;
	id handler = [NSNotificationCenter.defaultCenter addObserverForName:ULDocumentUnhandeledSaveErrorNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		notification = note;
	}];
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Reading failed");
	
	// Lock document access
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0} ofItemAtPath:url.path error:NULL];
	
	// Failing save
	[document saveWithCompletionHandler: nil];
	
	ULWaitOnAssertion(notification, @"Awaiting error notification");
	
	XCTAssertEqual(document, notification.object, @"Invalid object");
	XCTAssertEqualObjects(document.lastWriteError, notification.userInfo[ULDocumentUnhandeledSaveErrorNotificationErrorKey], @"Invalid error description");
	
	// Close document
	[document close];
	
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0666} ofItemAtPath:url.path error:NULL];
	
	[NSNotificationCenter.defaultCenter removeObserver: handler];
}

- (void)testPostingTimeoutNotificationsOnAsynchronousWrite
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	
	// Setup observer
	__block NSNotification *notification;
	id handler = [NSNotificationCenter.defaultCenter addObserverForName:ULDocumentUnhandeledSaveErrorNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		notification = note;
	}];
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Reading failed");
	
	// Lock document access
	__block BOOL isFileLocked = NO;
	
	dispatch_async_on_global_queue(^{
		[[[NSFileCoordinator alloc] initWithFilePresenter: nil] coordinateWritingItemAtURL:document.fileURL options:0 error:NULL byAccessor:^(NSURL * _Nonnull newURL) {
			isFileLocked = YES;
			[NSThread sleepForTimeInterval: 3];
			isFileLocked = NO;
		}];
	});
	
	ULWaitOnAssertion(isFileLocked, @"Test precondition: No simulated deadlock.");
	
	// Simulate change to trigger autosave
	document.text = @"Abc";
	break_undo_coalesing();
	
	// Perform failing save
	extern NSTimeInterval ULDocumentMaximumSaveDuration;
	NSTimeInterval oldSaveDuration = ULDocumentMaximumSaveDuration;
	ULDocumentMaximumSaveDuration = 2;
	
	[document autosaveWithCompletionHandler: nil];
	
	ULDocumentMaximumSaveDuration = oldSaveDuration;
	
	ULWaitOnAssertion(notification, @"Awaiting error notification");
	
	XCTAssertEqual(document, notification.object, @"Invalid object");
	XCTAssertEqualObjects(document.lastWriteError, notification.userInfo[ULDocumentUnhandeledSaveErrorNotificationErrorKey], @"Invalid error description");
	
	// Close document
	[document close];
	
	ULWaitOnAssertion(!isFileLocked, @"Test precondition:Simulated deadlock should end.");
	
	[NSNotificationCenter.defaultCenter removeObserver: handler];
}

- (void)testPostingErrorNotificationsOnSynchronousWrite
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	
	// Setup observer
	__block NSNotification *notification;
	id handler = [NSNotificationCenter.defaultCenter addObserverForName:ULDocumentUnhandeledSaveErrorNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		notification = note;
	}];
	
	// Open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Reading failed");
	
	// Lock document access
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0} ofItemAtPath:url.path error:NULL];
	
	// Failing save
	[document saveToURL:document.fileURL forSaveOperation:ULDocumentSave error:NULL];
	
	ULWaitOnAssertion(notification, @"Awaiting error notification");
	
	XCTAssertEqual(document, notification.object, @"Invalid object");
	XCTAssertEqualObjects(document.lastWriteError, notification.userInfo[ULDocumentUnhandeledSaveErrorNotificationErrorKey], @"Invalid error description");
	
	// Close document
	[document close];
	
	[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0666} ofItemAtPath:url.path error:NULL];
	
	[NSNotificationCenter.defaultCenter removeObserver: handler];
}

- (void)testOverlappingReadCloseRequests
{
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTAssertNotNil(document, @"Document not created");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not set");
	XCTAssertNil(document.fileModificationDate, @"No change date should be set");
	XCTAssertNil(document.changeDate, @"No change date should be set");
	XCTAssertFalse(document.documentIsOpen, @"Document should be closed yet");
	XCTAssertFalse(document.hasUnsavedChanges, @"Closed documents must not have any changes");
	
	
	// Double-request open document
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	} andOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Either opening failed");
	
	// Request open again
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	
	// Close document
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document closeWithCompletionHandler: handler];
	} andOperation:^(void (^handler)(BOOL)) {
		[document closeWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Closing failed");
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document closeWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Closing failed");
}

- (void)testDocumentCreation
{
	ULTestDocument *document = [ULTestDocument new];
	document.text = kTestText3;
	
	XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
	XCTAssertNil(document.fileURL, @"Should have no file URL yet");
	XCTAssertNil(document.fileModificationDate, @"File date shoudl be nil");
	
	
	// Write
	NSURL *url = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.txt", random()]];
	BOOL success  = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveToURL:url forSaveOperation:ULDocumentSave completionHandler:handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"File URL not updated");
	XCTAssertNotNil(document.fileModificationDate, @"File date not updated");
	XCTAssertFalse(document.hasUnsavedChanges, @"State should be cleared");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText3, @"Persistence mismatch");
	
	
	// Close
	[document close];
}

- (void)testDocumentMoving
{
	ULTestDocument *document = [ULTestDocument new];
	document.text = kTestText3;
	
	XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
	XCTAssertNil(document.fileURL, @"Should have no file URL yet");
	XCTAssertNil(document.fileModificationDate, @"File date shoudl be nil");
	
	
	// Write
	NSURL *url = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.txt", random()]];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveToURL:url forSaveOperation:ULDocumentSave completionHandler:handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	ULAssertEqualFileURLs(document.fileURL, url, @"File URL not updated");
	XCTAssertNotNil(document.fileModificationDate, @"File date not updated");
	XCTAssertFalse(document.hasUnsavedChanges, @"State should be cleared");
	XCTAssertNil(document.recognizedFilenameChange, @"Should not have notified new URL.");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText3, @"Persistence mismatch");
	
	
	// Write to other URL
	document.text = kTestText1;
	
	NSURL *newURL = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.txt", random()]];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveToURL:newURL forSaveOperation:ULDocumentSave completionHandler:handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	ULAssertEqualFileURLs(document.fileURL, newURL, @"File URL not updated");
	XCTAssertNotNil(document.fileModificationDate, @"File date not updated");
	XCTAssertFalse(document.hasUnsavedChanges, @"State should be cleared");
	XCTAssertEqualObjects(document.recognizedFilenameChange, newURL.lastPathComponent, @"Should have notified new URL.");
	
	XCTAssertFalse([url checkResourceIsReachableAndReturnError: NULL], @"Old File should have been moved.");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:newURL usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	
	
	// Close
	[document close];
}

- (void)testChangeTracking
{
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo stack not empty");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertEqualObjects(document.fileModificationDate, [url resourceValuesForKeys:@[NSURLContentModificationDateKey] error:NULL][NSURLContentModificationDateKey], @"Invalid modification date.");
	XCTAssertEqualObjects(document.changeToken, [document.class changeTokenForItemAtURL: url], @"Persistable change date should match modification date.");
	
	// Change text
	NSDate *fileChange = document.fileModificationDate;
	
	document.text = kTestText2;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	
	XCTAssertEqualObjects(fileChange, document.fileModificationDate, @"File change date should not change");
	XCTAssertNotNil(document.changeDate, @"Change date should be set");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	// Undo
	NSDate *lastChange = document.changeDate;
	id lastToken = document.changeToken;
	[document.undoManager undo];
	
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo should not be possible");
	XCTAssertTrue(document.undoManager.canRedo, @"Redo not registered");
	XCTAssertFalse(document.hasUnsavedChanges, @"Reverted document must not have any changes");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	// Redo
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	[document.undoManager redo];
	
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertFalse(document.undoManager.canRedo, @"Redo should not be possible");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	// Write to disk
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertFalse(document.undoManager.canRedo, @"Redo should not be possible");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.changeDate isEqual: lastChange], @"Change date should not updated");
	XCTAssertTrue([document.fileModificationDate	timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertEqualObjects(document.changeToken, [document.class changeTokenForItemAtURL: url], @"Persistable change date should match modification date.");
	
	
	// Undo
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	[document.undoManager undo];
	
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo should not be possible");
	XCTAssertTrue(document.undoManager.canRedo, @"Redo not registered");
	XCTAssertTrue(document.hasUnsavedChanges, @"Reverted document must have changes");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	
	// Edit again
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	document.text = kTestText3;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertFalse(document.undoManager.canRedo, @"Redo should not be possible");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	
	// Undo
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	[document.undoManager undo];
	
	XCTAssertFalse(document.undoManager.canUndo, @"Undo should not be possible");
	XCTAssertTrue(document.undoManager.canRedo, @"Redo not registered");
	XCTAssertTrue(document.hasUnsavedChanges, @"Reverted document must have changes");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	
	// Redo
	lastChange = document.changeDate;
	lastToken = document.changeToken;
	[document.undoManager redo];
	
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertFalse(document.undoManager.canRedo, @"Redo should not be possible");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: lastChange] > 0, @"Change date not updated");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	
	// Changes while writing to disk
	NSUInteger lastWriteCount = 0;
	NSDate *lastModificationDate = document.fileModificationDate;
	
	document.text = kTestText2;
	
	break_undo_coalesing();
	lastChange = document.changeDate;
	
	document.afterWriteLock = dispatch_semaphore_create(1);
	dispatch_semaphore_wait(document.afterWriteLock, DISPATCH_TIME_NOW);
	
	dispatch_async_on_global_queue(^{
		[document saveToURL:document.fileURL forSaveOperation:ULDocumentSave error:NULL];
	});
	
	ULWaitOnAssertion(document.writeCount > lastWriteCount, @"Test precondition failed: Write never occured.");
	
	[NSThread sleepForTimeInterval: 1];
	document.text = kTestText1;
	
	break_undo_coalesing();
	
	dispatch_semaphore_signal(document.afterWriteLock);
	
	ULWaitOnAssertion(document.fileModificationDate.timeIntervalSinceReferenceDate > lastModificationDate.timeIntervalSinceReferenceDate, @"Modification date should have changed");
	ULWaitOnAssertion(document.changeDate.timeIntervalSinceReferenceDate > lastChange.timeIntervalSinceReferenceDate, @"Modification date should have changed");
	XCTAssertTrue(document.changeDate.timeIntervalSinceReferenceDate > lastChange.timeIntervalSinceReferenceDate, @"Change date should have made progress");
	XCTAssertTrue(document.hasUnsavedChanges, @"Document should be marked as dirty.");
	
	XCTAssertFalse(document.changeDate.timeIntervalSinceReferenceDate == document.fileModificationDate.timeIntervalSinceReferenceDate, @"Change date should not match file modification date");
	XCTAssertFalse([document.changeToken isEqual: lastToken], @"Change token should be updated");
	XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
	
	
	// Close document
	[document close];
}

- (void)testChangeTrackingForInconsistentFormats
{
	ULTestDocumentUsesConsistentPersistenceFormat = NO;
	
	NSURL *url = [self createTestDocument];
	id oldChangeToken;
	
	@autoreleasepool {
		// Open document
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Opening failed");
		XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
		XCTAssertFalse(document.undoManager.canUndo, @"Undo stack not empty");
		XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
		XCTAssertEqualObjects(document.fileModificationDate, [url resourceValuesForKeys:@[NSURLContentModificationDateKey] error:NULL][NSURLContentModificationDateKey], @"Invalid modification date.");
		XCTAssertEqualObjects(document.changeToken, [document.class changeTokenForItemAtURL: url], @"Persistable change date should match modification date.");
		
		// Change text
		NSDate *fileChange = document.fileModificationDate;
		
		document.text = kTestText2;
		break_undo_coalesing();
		
		XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
		XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
		
		XCTAssertEqualObjects(fileChange, document.fileModificationDate, @"File change date should not change");
		XCTAssertNotNil(document.changeDate, @"Change date should be set");
		XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
		XCTAssertFalse([document.changeToken isEqual: [document.class changeTokenForItemAtURL: document.fileURL]], @"Persistable change date should not match persistent change token.");
		
		// Save
		oldChangeToken = document.changeToken;
		success = [self ul_performOperation:^(void (^handler)(BOOL)) { [document autosaveWithCompletionHandler: handler]; }];
		XCTAssertEqualObjects(document.changeToken, oldChangeToken, @"Change token should not have been change by save operation.");
	}
	
	// Re-opening the document should provide the persistent change token
	id persistentChangeToken;
	
	@autoreleasepool {
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success);
		XCTAssertNotEqualObjects(document.changeToken, oldChangeToken);
		
		persistentChangeToken = document.changeToken;
		XCTAssertNotNil(persistentChangeToken);
	}
	
	// Opening the document again: Change token should stay.
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success);
	XCTAssertEqualObjects(document.changeToken, persistentChangeToken);
	
}

- (void)testSaveOnClose
{
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo stack not empty");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	
	
	// Change text
	document.text = kTestText2;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	
	// Perform close
	NSDate *fileChange = document.fileModificationDate;
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document closeWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Closing failed");
	
	
	// Check last persisted state
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.fileModificationDate	timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
}

- (void)testSaveOnTermination
{
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo stack not empty");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	
	
	// Change text
	document.text = kTestText2;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	
	// Send app will terminate notification
	NSDate *fileChange = document.fileModificationDate;
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	
#if TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
	[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillTerminateNotification object:nil];
#else
	[NSNotificationCenter.defaultCenter postNotificationName:NSApplicationWillTerminateNotification object:nil];
#endif
	
	
	// Check last persisted state
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	XCTAssertTrue([document.fileModificationDate	timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	
	XCTAssertTrue(document.terminationNotified, @"Persistence mismatch");
	XCTAssertEqual(document.writeCount, 1, @"Write should have been triggered");
}

- (void)testClosedDocumentsShouldNotSaveOnTermination
{
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	XCTAssertFalse(document.undoManager.canUndo, @"Undo stack not empty");
	XCTAssertFalse(document.hasUnsavedChanges, @"Invalid change state");
	
	
	// Change text
	document.text = kTestText2;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.undoManager.canUndo, @"Undo not registered");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	[document close];
	
	ULWaitOnAssertion(!document.documentIsOpen, @"Document should be closed by deletion");
	
#if TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
	[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillTerminateNotification object:nil];
#else
	[NSNotificationCenter.defaultCenter postNotificationName:NSApplicationWillTerminateNotification object:nil];
#endif
	
	XCTAssertFalse(document.terminationNotified, @"Persistence mismatch");
	XCTAssertEqual(document.writeCount, 0, @"No write should have been triggered");
}

- (void)testAutomaticSaving
{
	// Short autosave delay for this test
	[ULDocument setAutosaveDelay: 0.1];
	
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	NSDate *fileChange = document.fileModificationDate;
	
	
	// Modify
	document.text = kTestText2;
	break_undo_coalesing();
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	// Wait for automatic save to happen
	[NSThread sleepForTimeInterval: 1.5]; // 0.1 is autosave delay, at most 1s for saving
	
	// Check
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	
	XCTAssertFalse(document.hasUnsavedChanges, @"Changes have not been autosaved");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	fileChange = document.fileModificationDate;
	
	// Modify again
	document.text = kTestText3;
	break_undo_coalesing();
	XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	// Wait for automatic save to happen
	[NSThread sleepForTimeInterval: 1.5]; // 0.1 is autosave delay
	
	// Check
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText3, @"Persistence mismatch");
	
	XCTAssertFalse(document.hasUnsavedChanges, @"Changes have not been autosaved");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	fileChange = document.fileModificationDate;
	
	// Undo
	[document.undoManager undo];
	XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
	XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
	
	// Wait for automatic save to happen
	[NSThread sleepForTimeInterval: 1.5]; // 0.1 is autosave delay
	
	// Check
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	
	XCTAssertFalse(document.hasUnsavedChanges, @"Changes have not been autosaved");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	
	// Close document
	[document close];
}

- (void)testAutosaveMemoryManagement
{
	// Short autosave delay for this test
	[ULDocument setAutosaveDelay: 0.1];
	
	NSURL *url = [self createTestDocument];
	__weak ULTestDocument *weakDocument;
	
	
	// Normal free
	@autoreleasepool {
		// Open document
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Opening failed");
		XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
		
		// Wait until all pending notifications have been processed
		[NSThread sleepForTimeInterval: 1.1];
		[[document valueForKey: @"interactionQueue"] waitUntilAllOperationsAreFinished];
		
		// Release reference, document should be cleaned up
		weakDocument = document;
		document = nil;
	}
	// It seems the runloop must run shortly for frees to happen
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
	XCTAssertNil(weakDocument, @"Document not released correctly");
	
	
	// Free by autosave
	@autoreleasepool {
		// Reopen
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Opening failed");
		XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
		
		// Modify
		document.text = kTestText2;
		break_undo_coalesing();
		XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
		XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
		
		// Release reference, document should be held by autosave
		weakDocument = document;
		document = nil;
	}
	// It seems the runloop must run shortly for frees to happen
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
	XCTAssertNotNil(weakDocument, @"Document should be kept in memory by autosave");
	
	// Wait for automatic save to happen
	[NSThread sleepForTimeInterval: 1.5]; // 0.1 is autosave delay
	
	ULWaitOnAssertion(!weakDocument, @"Document not cleaned up after autosave");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	
	
	// Free by manual save before autosave
	@autoreleasepool {
		// Reopen
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Opening failed");
		XCTAssertEqualObjects(document.text, kTestText2, @"Content mismatch");
		
		// Modify
		document.text = kTestText3;
		break_undo_coalesing();
		XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
		XCTAssertTrue(document.hasUnsavedChanges, @"Invalid change state");
		
		// Release reference, document should be held by autosave
		weakDocument = document;
		document = nil;
	}
	
	// It seems the runloop must run shortly for frees to happen
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
	ULWaitOnAssertion(!weakDocument, @"Document should be kept in memory by autosave");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText3, @"Persistence mismatch");
	
	
	@autoreleasepool {
		// Reopen
		ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
		BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document openWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Opening failed");
		XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
		
		document.text = kTestText1;
		
		// Manual save should free document as well
		success = [self ul_performOperation:^(void (^handler)(BOOL)) {
			[document saveWithCompletionHandler: handler];
		}];
		XCTAssertTrue(success, @"Saving failed");
		
		weakDocument = document;
	}
	// It seems the runloop must run shortly for frees to happen
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
	
	// Document should be freed now
	ULWaitOnAssertion(!weakDocument, @"Document not cleaned up after autosave");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
}

- (void)testSaveTo
{
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	NSDate *fileChange = document.fileModificationDate;
	
	
	// Modify document into dirty state
	document.text = kTestText2;
	break_undo_coalesing();
	XCTAssertTrue(document.hasUnsavedChanges, @"Document should be dirty");
	
	// Export document
	NSURL *otherURL = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: url.lastPathComponent];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveToURL:otherURL forSaveOperation:ULDocumentSaveTo completionHandler:handler];
	}];
	XCTAssertTrue(success, @"Exporting failed");
	
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL must not change");
	XCTAssertTrue(document.hasUnsavedChanges, @"Document should remain dirty!");
	XCTAssertEqualObjects(document.text, kTestText2, @"Content should not change");
	XCTAssertEqualObjects(document.fileModificationDate, fileChange, @"Change date mut not change");
	
	// Read in exported document
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:otherURL readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	XCTAssertFalse(document2.hasUnsavedChanges, @"Document should not be dirty!");
	XCTAssertEqualObjects(document2.text, kTestText2, @"Content mismatch");
	XCTAssertTrue([document2.fileModificationDate timeIntervalSinceDate: document.fileModificationDate] > 0, @"Exported file shoudl be newer");
}

- (void)testSaveKeepsPersistentURLAttributes
{
	NSDate *creationDateAttribute = [NSDate dateWithTimeIntervalSince1970: 1234];
	
	NSURL *url = [self createTestDocument];
	[url setResourceValue:creationDateAttribute forKey:NSURLCreationDateKey error:NULL];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	document.text = kTestText3;
	
	
	// Autosave document
	[self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Save failed.");
	
	[url removeAllCachedResourceValues];
	
	XCTAssertEqualObjects(url.ul_fileCreationDate, creationDateAttribute, @"Creation should be preserved.");
	
	
	// Move document
	NSURL *newURL = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: @"Test.txt"];
	[document saveToURL:newURL forSaveOperation:ULDocumentSave error:NULL];
	XCTAssertTrue(success, @"Save failed.");
	
	[newURL removeAllCachedResourceValues];
	
	XCTAssertEqualObjects(newURL.ul_fileCreationDate, creationDateAttribute, @"Creation should be preserved.");
	
	
	// Save document to explicit URL
	NSURL *newURL2 = [self.ul_newTemporarySubdirectory URLByAppendingPathComponent: @"Test-2.txt"];
	[document saveToURL:newURL2 forSaveOperation:ULDocumentSaveTo error:NULL];
	XCTAssertTrue(success, @"Save failed.");
	
	[newURL2 removeAllCachedResourceValues];
	
	XCTAssertEqualObjects(newURL2.ul_fileCreationDate, creationDateAttribute, @"Creation should be preserved.");
}

- (void)testDeletion
{
	NSURL *url = [self createTestDocument];
	
	// Open documents
	ULTestDocument *document1 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	
	// Check contents
	XCTAssertEqualObjects(document1.text, kTestText1, @"Content mismatch");
	XCTAssertEqualObjects(document2.text, kTestText1, @"Content mismatch");
	XCTAssertEqualObjects(document1.fileModificationDate, document2.fileModificationDate, @"Change date mismatch");
	
	
	// Perform deletion
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 deleteWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Deletion failed");
	
	// Wait for deletion to map into other document
	ULWaitOnAssertions(
					   ULAwaitedAssertion(!document2.fileModificationDate, @"Not properly closed")
					   );
	
	
	// Check documents have been closed
	XCTAssertFalse(document1.documentIsOpen, @"Document not closed");
	XCTAssertFalse(document2.documentIsOpen, @"Document not closed");
	XCTAssertNil(document1.fileModificationDate, @"Change date not cleared");
	XCTAssertNil(document2.fileModificationDate, @"Change date not cleared");
	XCTAssertNil(document1.changeDate, @"Change date not cleared");
	XCTAssertNil(document2.changeDate, @"Change date not cleared");
	XCTAssertFalse(document1.hasUnsavedChanges, @"Change state not cleared");
	XCTAssertFalse(document2.hasUnsavedChanges, @"Change state not cleared");
}

- (void)testFileCoordinationWithContent
{
	NSURL *url = [self createTestDocument];
	
	// Open documents
	ULTestDocument *document1 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	
	// Check contents
	XCTAssertEqualObjects(document1.text, kTestText1, @"Content mismatch");
	XCTAssertEqualObjects(document2.text, kTestText1, @"Content mismatch");
	XCTAssertEqualObjects(document1.fileModificationDate, document2.fileModificationDate, @"Change date mismatch");
	NSDate *fileChange = document1.fileModificationDate;
	
	
	// Change and write document 1
	document1.text = kTestText2;
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 saveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText2, @"Persistence mismatch");
	XCTAssertTrue([document1.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"File change date should update");
	XCTAssertTrue([document1.fileModificationDate timeIntervalSinceDate: document2.fileModificationDate] > 0, @"File change date should not yet update");
	fileChange = document1.fileModificationDate;
	
	
	// Wait for changes to map into document 2
	ULWaitOnAssertions(
					   ULAwaitedAssertion([document2.text isEqual: kTestText2], @"Text not loaded"),
					   ULAwaitedAssertion([document1.fileModificationDate isEqualToDate: fileChange], @"File change date should not update"),
					   ULAwaitedAssertion([document2.fileModificationDate isEqualToDate: document1.fileModificationDate], @"File change date should update")
					   );
	
	// Change and write document 2
	document2.text = kTestText1;
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 saveWithCompletionHandler: handler];
	}];
	
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:url usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	fileChange = document2.fileModificationDate;
	
	// Change again before doc 1 reads
	document2.text = kTestText3;
	
	break_undo_coalesing();
	XCTAssertTrue(document2.hasUnsavedChanges, @"Document not dirty as it should be");
	
	// Trigger autosave
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 autosaveWithCompletionHandler: handler];
	}];
	
	// Wait for changes to map into document 1
	ULWaitOnAssertions(
					   ULAwaitedAssertion([document1.fileModificationDate isEqual: document2.fileModificationDate], @"Change date mismatch"),
					   ULAwaitedAssertion([document1.text isEqual: kTestText3], @"Text not loaded correctly")
					   );
	
	// Check that document 2 was written
	XCTAssertFalse(document2.hasUnsavedChanges, @"Changes not written as they should");
	XCTAssertTrue([document2.fileModificationDate timeIntervalSinceDate: fileChange] >= 0, @"Date not updated");
	
	// Close
	[document1 close];
	[document2 close];
}

- (void)testDoNotRevertOnStaleChangeNotifications
{
	// Open two instances of the same document
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	// Modify document 1 internally without saving
	document.text = kTestText3;
	break_undo_coalesing();
	id document1Token = document.changeToken;
	
	XCTAssertTrue(document.hasUnsavedChanges, @"Document should be dirty");
	XCTAssertFalse([document.changeToken isEqual: [ULTestDocument changeTokenForItemAtURL: url]], @"Change token of unsaved document should diverge from file system state.");
	
	
	// Simulate a stale change notification
	[document presentedItemDidChange];
	[NSThread sleepForTimeInterval: 1];
	
	// Unsaved document should not be reverted
	XCTAssertEqualObjects(document.text, kTestText3, @"Content should not be changed");
	
	XCTAssertEqualObjects(document.changeToken, document1Token, @"Change token of unsaved document should not be changed");
	XCTAssertFalse([document.changeToken isEqual: [ULTestDocument changeTokenForItemAtURL: url]], @"Change token of unsaved document should diverge from file system state.");
	
	
	// Modify file on disk: document should be reverted
	[NSThread sleepForTimeInterval: 1];
	[kTestText2 writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	
	ULWaitOnAssertion([document.text isEqual: kTestText2], @"Content should be changed");
}

- (void)testFileCoordinationWithFileEvents
{
	NSURL *url = [self createTestDocument];
	
	// Open documents
	ULTestDocument *document1 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	NSDate *fileChange = document1.fileModificationDate;
	
	
	// Move file
	NSURL *oldURL = url;
	url = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent: [NSString stringWithFormat: @"file%lx.txt", random()]];
	
	NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
	[coordinator coordinateWritingItemAtURL:oldURL options:NSFileCoordinatorWritingForMoving writingItemAtURL:url options:0 error:NULL byAccessor:^(NSURL *newURL1, NSURL *newURL2) {
		XCTAssertEqualObjects(oldURL, newURL1, @"URL mismatch");
		XCTAssertEqualObjects(url, newURL2, @"URL mismatch");
		
		XCTAssertTrue([NSFileManager.defaultManager moveItemAtURL:oldURL toURL:url error:NULL], @"Move failed");
		[coordinator itemAtURL:oldURL didMoveToURL:url];
	}];
	
	// Check urls
	XCTAssertTrue([document1.fileURL ul_isEqualToFileURL: oldURL], @"URL mismatch");
	XCTAssertTrue([document2.fileURL ul_isEqualToFileURL: oldURL], @"URL mismatch");
	
	
	// Wait for changes to map into documents
	ULWaitOnAssertions(
					   ULAwaitedAssertion([document1.fileURL ul_isEqualToFileURL: url], @"URL not updated"),
					   ULAwaitedAssertion([document2.fileURL ul_isEqualToFileURL: url], @"URL not updated"),
					   );
	
	// Check urls and change state
	XCTAssertTrue([document1.fileURL ul_isEqualToFileURL: url], @"URL not updated");
	XCTAssertTrue([document2.fileURL ul_isEqualToFileURL: url], @"URL not updated");
	XCTAssertEqualObjects(document1.fileModificationDate, fileChange, @"Change date should not change");
	XCTAssertEqualObjects(document2.fileModificationDate, fileChange, @"Change date should not change");
	
	
	// Make files dirty
	document1.text = kTestText3;
	break_undo_coalesing();
	
	XCTAssertNotNil(document1.changeDate, @"Document should be dirty");
	XCTAssertTrue(document1.hasUnsavedChanges, @"Document should be dirty");
	
	
	// Delete file
	[[[NSFileCoordinator alloc] initWithFilePresenter: nil] coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForDeleting error:NULL byAccessor:^(NSURL *newURL) {
		XCTAssertTrue([url ul_isEqualToFileURL: newURL], @"URL mismatch");
		XCTAssertTrue([NSFileManager.defaultManager removeItemAtURL:url error:NULL], @"Remove failed");
	}];
	
	
	// Wait for changes to map into documents
	ULWaitOnAssertions(
					   ULAwaitedAssertion(!document1.fileModificationDate, @"Not properly closed"),
					   ULAwaitedAssertion(!document2.fileModificationDate, @"Not properly closed"),
					   );
	
	// Check documents have been closed
	XCTAssertFalse(document1.documentIsOpen, @"Document not closed");
	XCTAssertFalse(document2.documentIsOpen, @"Document not closed");
	XCTAssertNil(document1.fileModificationDate, @"Change date not cleared");
	XCTAssertNil(document2.fileModificationDate, @"Change date not cleared");
	XCTAssertNil(document1.changeDate, @"Change date not cleared");
	XCTAssertNil(document2.changeDate, @"Change date not cleared");
	XCTAssertFalse(document1.hasUnsavedChanges, @"Change state not cleared");
	XCTAssertFalse(document2.hasUnsavedChanges, @"Change state not cleared");
}

- (void)testUpdatesOnPackageItemChanges
{
	ULTestDocumentShouldHandleSubitemChanges = YES;
	
	// Create package
	NSURL *documentURL = [[self ul_newTemporarySubdirectory] URLByAppendingPathComponent: @"test.package"];
	ULTestDocument *packageDocument = [[ULTestDocument alloc] initWithFileURL:documentURL readOnly:NO];
	NSString *initialChangeToken = packageDocument.changeToken;
	
	packageDocument.text = kTestText1;
	break_undo_coalesing();
	NSString *temporaryChangeToken = packageDocument.changeToken;
	XCTAssertNotEqualObjects(temporaryChangeToken, initialChangeToken);
	
	[self ul_performOperation:^(void (^completionHandler)(BOOL)) {
		[packageDocument saveWithCompletionHandler: completionHandler];
	}];
	
	NSString *changeToken1 = packageDocument.changeToken;
	XCTAssertNotEqualObjects(changeToken1, temporaryChangeToken);
	
	
	// Modify contents file. Change token should updateand file should be reloaded
	NSURL *contentURL = [documentURL URLByAppendingPathComponent: @"content.txt"];
	[[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:contentURL options:0 error:NULL byAccessor:^(NSURL * _Nonnull newURL) {
		[kTestText2 writeToURL:contentURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}];
	
	ULWaitOnEqualObjects(packageDocument.text, kTestText2);
	ULWaitOnAssertion(![changeToken1 isEqual: packageDocument.changeToken]);
	
	
	// Modify another file: The change token should change and the file should be reloaded.
	NSString *changeToken2 = packageDocument.changeToken;
	
	NSURL *otherfileURL = [documentURL URLByAppendingPathComponent: @"anyFile.txt"];
	[[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:otherfileURL options:0 error:NULL byAccessor:^(NSURL * _Nonnull newURL) {
		[@"Other" writeToURL:otherfileURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}];
	
	ULWaitOnAssertion(![changeToken2 isEqual: packageDocument.changeToken]);
	ULWaitOnEqualObjects(packageDocument.text, kTestText2);
}

- (void)testReadOnlyInstance
{
	NSURL *url = [self createTestDocument];
	
	// Open documents
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	ULTestDocument *documentReadOnly = [[ULTestDocument alloc] initWithFileURL:url readOnly:YES];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[documentReadOnly openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	NSDate *fileChange = document.fileModificationDate;
	
	
	// Try modifying read-only sheet
	documentReadOnly.text = kTestText3;
	XCTAssertThrows([NSRunLoop.currentRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.0001]], @"Document must not allow modifications");
	
	// Change file
	[NSThread sleepForTimeInterval: 1.0];
	
	NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
	[coordinator coordinateWritingItemAtURL:url options:0 error:NULL byAccessor:^(NSURL *newURL) {
		XCTAssertEqualObjects(url, newURL, @"URL mismatch");
		
		XCTAssertTrue([kTestText2 writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:NULL], @"Move failed");
	}];
	
	// Wait for changes to map into documents
	ULWaitOnAssertions(
					   ULAwaitedAssertion([document.text isEqual: kTestText2], @"URL not updated"),
					   ULAwaitedAssertion([documentReadOnly.fileURL ul_isEqualToFileURL: url], @"URL not updated"),
					   );
	
	// Check urls and change state
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL changed");
	XCTAssertTrue([documentReadOnly.fileURL ul_isEqualToFileURL: url], @"URL changed");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: fileChange] > 0, @"Change date should change");
	XCTAssertEqualObjects(documentReadOnly.fileModificationDate, fileChange, @"Change date should not change");
	
	
	// Move file
	NSURL *oldURL = url;
	url = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent: [NSString stringWithFormat: @"file%lx.txt", random()]];
	
	[coordinator coordinateWritingItemAtURL:oldURL options:NSFileCoordinatorWritingForMoving writingItemAtURL:url options:0 error:NULL byAccessor:^(NSURL *newURL1, NSURL *newURL2) {
		XCTAssertEqualObjects(oldURL, newURL1, @"URL mismatch");
		XCTAssertEqualObjects(url, newURL2, @"URL mismatch");
		
		XCTAssertTrue([NSFileManager.defaultManager moveItemAtURL:oldURL toURL:url error:NULL], @"Move failed");
		[coordinator itemAtURL:oldURL didMoveToURL:url];
	}];
	
	// Check urls
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: oldURL], @"URL mismatch");
	XCTAssertTrue([documentReadOnly.fileURL ul_isEqualToFileURL: oldURL], @"URL mismatch");
	
	// Wait for changes to map into documents
	ULWaitOnAssertions(
					   ULAwaitedAssertion([document.fileURL ul_isEqualToFileURL: url], @"URL not updated"),
					   ULAwaitedAssertion([document.recognizedMoveURL ul_isEqualToFileURL: url], @"Should notify about move.")
					   );
	
	// Check urls and change state
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: url], @"URL not updated");
	XCTAssertTrue([documentReadOnly.fileURL ul_isEqualToFileURL: oldURL], @"URL not updated");
	XCTAssertTrue([document.changeDate timeIntervalSinceDate: fileChange] > 0, @"Change date should change");
	XCTAssertEqualObjects(documentReadOnly.fileModificationDate, fileChange, @"Change date should not change");
}

- (void)testClosedDocumentsShouldRemoveFilePresentersFromNSFileCoordinator {
	NSURL *url = [self createTestDocument];
	
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[document openWithCompletionHandler:^(BOOL success) {
		XCTAssertTrue([NSFileCoordinator filePresenters].count == 1);
		XCTAssertTrue(success, @"Can't open document");
	}];
	
	[document closeWithCompletionHandler:^(BOOL success) {
		XCTAssertTrue([NSFileCoordinator filePresenters].count == 0, @"File presenter not removed.");
		[expectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		NSLog(@"Error waiting for expectation: %@", error);
	}];
}


#if !TARGET_OS_IPHONE

- (void)testVersionPreservation
{
	// Short autosave delay for this test
	[ULDocument setAutosaveDelay: 0.1];
	
	NSURL *url = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	NSDate *originalDate = document.fileModificationDate;
	
	
	// Get/check file version
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL: url];
	XCTAssertNotNil(currentVersion, @"No current version?");
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, originalDate.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	
	// Make change and autosave
	document.text = kTestText2;
	break_undo_coalesing();
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: originalDate] > 0, @"Change date not updated");
	NSDate *changeDate1 = document.fileModificationDate;
	
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	
	// Make change and do an EXPLICIT save
	document.text = kTestText3;
	break_undo_coalesing();
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: changeDate1] > 0, @"Change date not updated");
	NSDate *changeDate2 = document.fileModificationDate;
	
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate2.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	XCTAssertEqual([NSFileVersion otherVersionsOfItemAtURL: url].count, 1lu, @"There should be one other version");
	NSFileVersion *otherVersion1 = [NSFileVersion otherVersionsOfItemAtURL: url][0];
	XCTAssertEqualWithAccuracy(otherVersion1.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:otherVersion1.URL encoding:NSUTF8StringEncoding error:NULL], kTestText2, @"Invalid version content.");
	
	// Repeat save without change
	break_undo_coalesing();
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: changeDate2] > 0, @"Change date not updated");
	NSDate *changeDate3 = document.fileModificationDate;
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate3.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	XCTAssertEqual([NSFileVersion otherVersionsOfItemAtURL: url].count, 1lu, @"There should be one other version");
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[ otherVersion1 ], @"Other versions should not change");
	XCTAssertEqualWithAccuracy(otherVersion1.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");	// Used to be originalDate2 on 10.9. See -testWrongVersionModificationDateOnYosemite
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:otherVersion1.URL encoding:NSUTF8StringEncoding error:NULL], kTestText2, @"Invalid version content.");
	
	// Wait until time has progressed enough to trigger autosave
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
	
	// Make change and wait for autosave
	document.text = kTestText1;
	break_undo_coalesing();
	
	[NSThread sleepForTimeInterval: 0.5]; // 0.1 is autosave delay
	
	// Makesure changes were written
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: changeDate3] > 0, @"Change date not updated");
	NSDate *changeDate4 = document.fileModificationDate;
	
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate4.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[ otherVersion1 ], @"There should be one other version");
	XCTAssertEqualWithAccuracy(otherVersion1.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:otherVersion1.URL encoding:NSUTF8StringEncoding error:NULL], kTestText2, @"Invalid version content.");
	
	// Close
	[document close];
}

- (void)testVersionAutocreation
{
	// Short autoversioning interval for this test
	[ULDocument setAutoversioningInterval: 0.3];
	
	NSURL *url = [self createTestDocument];
	NSURL *url2 = [self createTestDocument];
	
	// Open document
	ULTestDocument *document = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document.text, kTestText1, @"Content mismatch");
	NSDate *originalDate = document.fileModificationDate;
	
	
	// Get/check file version
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL: url];
	XCTAssertNotNil(currentVersion, @"No current version?");
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, originalDate.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	
	// Wait until time has progressed enough to make for a date change on the file system
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	
	// Do a write, should not update version
	document.text = kTestText3;
	break_undo_coalesing();
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: originalDate] > 0, @"Change date not updated");
	NSDate *changeDate1 = document.fileModificationDate;
	
	XCTAssertEqualObjects(currentVersion, [NSFileVersion currentVersionOfItemAtURL: url], @"Version should not change");
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	
	// Wait until time has progressed enough to reach autosave version interval
	[NSRunLoop.mainRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.4]];
	
	// Make change and autosave
	document.text = kTestText2;
	break_undo_coalesing();
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: changeDate1] > 0, @"Change date not updated");
	NSDate *changeDate2 = document.fileModificationDate;
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate2.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	ULWaitOnAssertion([NSFileVersion otherVersionsOfItemAtURL: url].count == 1ul, @"No new version created");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
	
	NSFileVersion *previousVersion = [NSFileVersion otherVersionsOfItemAtURL: url][0];
	XCTAssertFalse([currentVersion isEqual: previousVersion], @"Versions should have changed");
	XCTAssertEqualWithAccuracy(previousVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate1.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch"); // Used to be changeDate1 on 10.9. See -testWrongVersionModificationDateOnYosemite
	
	
	
	// Init a new document with an older URL
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:url2 readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	originalDate = document2.fileModificationDate;
	
	XCTAssertTrue(success, @"Opening failed");
	XCTAssertEqualObjects(document2.text, kTestText1, @"Content mismatch");
	
	// Get/check file version
	NSFileVersion *currentVersion2 = [NSFileVersion currentVersionOfItemAtURL: url2];
	XCTAssertNotNil(currentVersion2, @"No current version?");
	XCTAssertEqualWithAccuracy(currentVersion2.modificationDate.timeIntervalSinceReferenceDate, originalDate.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url2], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url2].count, 0ul, @"There should be no conflict versions");
	
	// Perfrom save, should not create a new version
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileModificationDate timeIntervalSinceDate: originalDate] > 0, @"Change date not updated");
	NSDate *changeDate3 = document.fileModificationDate;
	
	XCTAssertEqualObjects(currentVersion, [NSFileVersion currentVersionOfItemAtURL: url2], @"Version should not change");
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, changeDate3.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqualObjects([NSFileVersion otherVersionsOfItemAtURL: url2], @[], @"There should be no other versions");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url2].count, 0ul, @"There should be no conflict versions");
	
	// Do a write, should update version
	document2.text = kTestText3;
	break_undo_coalesing();
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document2.fileModificationDate timeIntervalSinceDate: changeDate3] > 0, @"Change date not updated");
	NSDate *changeDate4 = document2.fileModificationDate;
	
	
	// Get/check file version
	XCTAssertEqualWithAccuracy(currentVersion2.modificationDate.timeIntervalSinceReferenceDate, changeDate4.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqual([NSFileVersion otherVersionsOfItemAtURL: url2].count, 1ul, @"No new version created");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url2].count, 0ul, @"There should be no conflict versions");
	
	NSFileVersion *previousVersion2 = [NSFileVersion otherVersionsOfItemAtURL: url2][0];
	XCTAssertFalse([currentVersion2 isEqual: previousVersion2], @"Versions should have changed");
	XCTAssertEqualWithAccuracy(previousVersion2.modificationDate.timeIntervalSinceReferenceDate, originalDate.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
}


- (void)testConflictManagement
{
	NSURL *url = [self createTestDocument];
	
	// Open documents
	ULTestDocument *document1 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	
	ULTestDocument *document2 = [[ULTestDocument alloc] initWithFileURL:url readOnly:NO];
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document2 openWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Opening failed");
	NSDate *fileChange = document1.fileModificationDate;
	
	
	// Edit both
	document1.text = kTestText2;
	document2.text = kTestText3;
	break_undo_coalesing();
	
	
	// Save one, should trigger autosave of 2
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document1 autosaveWithCompletionHandler: handler];
	}];
	XCTAssertTrue(success, @"Writing failed");
	
	
	// Wait for changes to map into documents
	ULWaitOnAssertions(
					   ULAwaitedAssertion(!document1.hasUnsavedChanges, @"Document 1 should have been persisted"),
					   ULAwaitedAssertion(!document2.hasUnsavedChanges, @"Document 1 should have been persisted")
					   );
	
	// Check that both were written
	XCTAssertTrue([document1.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"Change date not updated");
	XCTAssertTrue([document2.fileModificationDate timeIntervalSinceDate: fileChange] > 0, @"Change date not updated");
	
	// Get/check file version
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL: url];
	XCTAssertNotNil(currentVersion, @"No current version?");
	XCTAssertEqualWithAccuracy(currentVersion.modificationDate.timeIntervalSinceReferenceDate, document1.fileModificationDate.timeIntervalSinceReferenceDate, 0.5f, @"Change date mismatch");
	XCTAssertEqual([NSFileVersion unresolvedConflictVersionsOfItemAtURL: url].count, 0ul, @"There should be no conflict versions");
}

- (void)testUnavailableVersionStore
{
	[ULDocument setAutoversioningInterval: 0.1];
	
	NSURL *volumeURL = [self ul_newDummyFileSystemWithType:ULTestCaseMSDOSFileSystemType size:5];
	
	// Create a document inside it
	ULTestDocument *document = [ULTestDocument new];
	document.text = kTestText3;
	break_undo_coalesing();
	
	XCTAssertEqualObjects(document.text, kTestText3, @"Content mismatch");
	XCTAssertNil(document.fileURL, @"Should have no file URL yet");
	XCTAssertNil(document.fileModificationDate, @"File date shoudl be nil");
	
	
	// Write new document
	NSURL *documentURL = [volumeURL URLByAppendingPathComponent: [NSString stringWithFormat: @"test%lx.txt", random()]];
	
	BOOL success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document saveToURL:documentURL forSaveOperation:ULDocumentSave completionHandler:handler];
	}];
	
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: documentURL], @"File URL not updated");
	XCTAssertNotNil(document.fileModificationDate, @"File date not updated");
	XCTAssertFalse(document.hasUnsavedChanges, @"State should be cleared");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:documentURL usedEncoding:NULL error:NULL], kTestText3, @"Persistence mismatch");
	
	// Wait some time
	[[NSRunLoop mainRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
	
	// Update document
	document.text = kTestText1;
	break_undo_coalesing();
	
	
	success = [self ul_performOperation:^(void (^handler)(BOOL)) {
		[document autosaveWithCompletionHandler: handler];
	}];
	
	// Should not create a document version, since the FS doesn't support it
	NSArray *allVersions = [NSFileVersion otherVersionsOfItemAtURL: documentURL];
	XCTAssertEqual(allVersions.count, 0UL, @"Version store should not be available on FAT.");
	
	// But should save properly
	XCTAssertTrue(success, @"Writing failed");
	XCTAssertTrue([document.fileURL ul_isEqualToFileURL: documentURL], @"File URL not updated");
	XCTAssertNotNil(document.fileModificationDate, @"File date not updated");
	XCTAssertFalse(document.hasUnsavedChanges, @"State should be cleared");
	
	XCTAssertEqualObjects([NSString stringWithContentsOfURL:documentURL usedEncoding:NULL error:NULL], kTestText1, @"Persistence mismatch");
	
	// Close
	[document close];
	
	// Unmount temporary file system
	[self ul_unmountDummyFilesystemAtURL: volumeURL];
}
#endif

@end
