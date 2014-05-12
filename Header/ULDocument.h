//
//	ULDocument.h
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

/*!
 @abstract The kind of changes known to ULDocument.
 @discussion The first four constants describe the type of change done whereas the latter define options to pass along the change notifications.
 
 @const ULDocumentChangeDone		A change was done to the document.
 @const ULDocumentChangeUndone		A previously done/redone change was undone on the document.
 @const ULDocumentChangeUndone		A previously undone change was redone on the document.
 @const ULDocumentChangeCleared		The current state of the document reflects the state on disk.
 
 @const ULDocumentChangeNotUndoable	The passed type of change cannot be undone. Only applies to ULDocumentChangeDone, ULDocumentChangeUndone and ULDocumentChangeRedone respectively.
 */
typedef enum : NSUInteger {
    ULDocumentChangeDone		= 0,
    ULDocumentChangeUndone		= 1,
    ULDocumentChangeRedone		= 2,
    ULDocumentChangeCleared		= 3,
	
    ULDocumentChangeNotUndoable	= 1 << 8
} ULDocumentChangeKind;


/*!
 @abstract The kind of save operations known to ULDocument.
 
 @const ULDocumentSave		The document was saved by explicit user action. This usually creates a new version of the document on disk. If the URL of the document changed, the document is moved.
 @const ULDocumentAutosave	The document was saved due to an implicitly triggered event, like a timer. Does not create versions. If the URL of the document changed, the document is moved.
 @const ULDocumentSaveAs	The document was saved by explicit user action to a new URL. This creates a new version of the document on disk, while the original document is kept.
 @const ULDocumentSaveTo	The document is supposed to be written to some URL by explicit user action. This is like an "Export" kind of functionality, not changing the receiving document but just writing out a copy.
 */
typedef enum : NSUInteger {
	ULDocumentSave		= 0,
	ULDocumentAutosave	= 1,
	ULDocumentSaveAs	= 2,
	ULDocumentSaveTo	= 3
} ULDocumentSaveOperation;

/*!
 @abstract A notification that is sent whenever an error during a save operation was not handled.
 @discussion The passed object contains the errorneous instance of ULDocument. The error message can be accessed from the userInfo of the notification using the key ULDocumentUnhandeledSaveErrorNotificationErrorKey.
 */
extern NSString *ULDocumentUnhandeledSaveErrorNotification;

/*!
 @abstract Used in the dictionary passed as object value of a ULDocumentUnhandeledSaveErrorNotification. References the actual NSError message.
 */
extern NSString *ULDocumentUnhandeledSaveErrorNotificationErrorKey;


/*!
 @abstract Abstract document class like NSDocument, modelled after UIDocument for headless operation.
 */
@interface ULDocument : NSObject

/*!
 @abstract The file type suppored by the concrete document class.
 @discussion Must be overwritten by subclassers.
 */
+ (NSString *)defaultFileType;

/*!
 @abstract The preferred path extension for instances of the concrete document class.
 @discussion Must be overwritten by subclassers.
 */
+ (NSString *)defaultPathExtension;

/*!
 @abstract Allows clients to globally configure the delay of autosave operations.
 @discussion Defaults to 30 seconds.
 */
+ (void)setAutosaveDelay:(NSTimeInterval)delay;

/*!
 @abstract Allows clients to globally configure the minimum time between automatically generated document version.
 @discussion Only applicable on OS X. Defaults to 15 minutes. Setting this to 0 disables automatic versioning.
 */
+ (void)setAutoversioningInterval:(NSTimeInterval)interval;


#pragma mark - General properties

/*!
 @abstract Designated initializer.
 @discussion The passed URL must not be nil, will raise otherwise. Passing YES for readOnly will return a one-shot copy of the document that is not registered as a file presenter and will thus not receive subsequent external changes.
 */
- (id)initWithFileURL:(NSURL *)url readOnly:(BOOL)readOnly;

/*!
 @abstract The currently used URL of the document.
 @discussion Will update as the document is moved and/or renamed on disk.
 */
@property(readonly) NSURL *fileURL;

/*!
 @abstract The file type of the current document.
 */
@property(readonly) NSString *fileType;

/*!
 @abstract Whether the document is a lightweight read-only instance.
 @discussion If YES, any modifications made to the receivers's contens are supposed to raise.
 */
@property(readonly) BOOL isReadOnly;

/*!
 @abstract The filename that should be used in the next write operation.
 @discussion Override point for subclasses, default implementation returns fileURL's last path component. Should not do any name sanitation, which is supposed to be done elsewhere, e.g. the document classes does this in -URLForSaveOperation:.
 */
@property(readonly) NSString *preferredFilename;

/*!
 @abstract A path extension of a concrete instance that should be used when sanitizing the filename of a document.
 @discussion Defaults to defaultPathExtension.
 */
@property(readonly) NSString *sanitizedPathExtension;

/*!
 @abstract Returns wether the document is currently mapped into memory or not.
 */
@property(readonly) BOOL documentIsOpen;

/*!
 @abstract The date of the last known modification on disk.
 */
@property(readonly) NSDate *fileModificationDate;

/*!
 @abstract The date of the last time the document was read from disk.
 @discussion This includes the initial open as well as every revert.
 */
@property(readonly) NSDate *lastFileOpenDate;

/*!
 @abstract The error of the last read operation.
 @discussion Will be set by -openWithCompletionHandler:
 */
@property(readonly) NSError *lastReadError;

/*!
 @abstract The error of the last write operation.
 @discussion Will be set by -saveWithCompletionHandler:, and -autosaveWithCompletionHandler:. Might change asynchronously if the document was autosaved.
 */
@property(readonly) NSError *lastWriteError;


#pragma mark - Document lifecycle

/*!
 @abstract Open the document located by the fileURL.
 @discussion This will call readFromURL:error: on a background queue and then invoke the completionHandler on a background queue. The error code will be set to lastReadError.
 */
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Explicitly save the document to disk.
 @discussion Unlike the autosave happening after any changes, this method not only saves the contents but (on Mac OS) also creates a new version of the file on disk. The completionHandler will be called on a background queue. Passes NO to the completion handler, if an error occured. The error code will be set to lastWriteError. If an error occurs and no completion handler is provided a ULDocumentUnhandeledSaveErrorNotification is posted.
 */
- (void)saveWithCompletionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Saves the document's current state to the fileURL.
 @discussion This method does usually not have to called directly. The completionHandler will be called on a background queue. Passes NO to the completion handler, if an error occured. The error code will be set to lastWriteError. If an error occurs and no completion handler is provided a ULDocumentUnhandeledSaveErrorNotification is posted.
 */
- (void)autosaveWithCompletionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Close the document.
 @discussion Calls [self autosaveWithCompletionHandler:completionHandler] which will save if [self hasUnsavedChanges] returns YES. The completionHandler will be called on a background queue. If an error occurs and no completion handler is provided a ULDocumentUnhandeledSaveErrorNotification is posted.
 */
- (void)closeWithCompletionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Delete the document.
 @discussion Deletes the item at the document's current file URL and as a result also closes the document. The completionHandler will be called on a background queue.
 */
- (void)deleteWithCompletionHandler:(void (^)(BOOL success))completionHandler;


#pragma mark - Advanced reading and writing

/*!
 @abstract Synchronously reads the document's contents from the specified URL.
 */
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;

/*!
 @abstract Synchronously opens the document from the specified URL.
 @discussion WARNING: This method does not do any file coordination but expects the caller to do so! Will synchronously read the document from disk, updating/initializing all the document's properties successful completion. Should rarely be called directly.
 */
- (BOOL)coordinatedOpenFromURL:(NSURL *)url error:(NSError **)outError;

/*!
 @abstract Primary entry point for initiating a save.
 @discussion Will asynchronously write the document to disk, updating the document's fileURL upon successful completion. Depending on the save operation, a new version will be added to the versions store or not. This method essentiall just calls -saveToURL:forSaveOperation:error: asynchronously. The completionHandler will be called on a background queue. Passes NO to the completion handler, if an error occured. The error code will be set to lastWriteError. If an error occurs and no completion handler is provided a ULDocumentUnhandeledSaveErrorNotification is posted.
 */
- (void)saveToURL:(NSURL *)url forSaveOperation:(ULDocumentSaveOperation)saveOperation completionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Synchronously write the document to the specified URL.
 @discussion Will synchronously write the document to disk, updating the document's fileURL upon successful completion. Depending on the save operation, a new version will be added to the versions store or not. If the passed URL differs from the documents current file URL, and depending on the operation, the current item will first be moved to the passed URL before being overwritten. Should not be called directly if asynchronous saving is possible. If an error occurs and no output argument 'error' is provided a ULDocumentUnhandeledSaveErrorNotification is posted.
 */
- (BOOL)saveToURL:(NSURL *)url forSaveOperation:(ULDocumentSaveOperation)saveOperation error:(NSError **)outError;

/*!
 @abstract Resets the document to the file at the specified URL.
 @discusison The completionHandler will be called on a background queue.
 */
- (void)revertToContentsOfURL:(NSURL *)url completionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @abstract Synchronously write the document to the specified URL.
 @discussion WARNING: This method does not do any file coordination but expects the caller to do so! Will synchronously write the document to disk, updating the document's fileURL upon successful completion. Depending on the save operation, a new version will be added to the versions store or not. Should rarely be called directly.
 */
- (BOOL)coordinatedSaveToURL:(NSURL *)url forSaveOperation:(ULDocumentSaveOperation)saveOperation error:(NSError **)outError;


#pragma mark - Change Management

/*!
 @abstract Indicates whether the document has any unsaved changes.
 */
@property(nonatomic, readonly) BOOL hasUnsavedChanges;

/*!
 @abstract Returns the last date of any modification of the document since it was opened.
 @discussion Will be updated whenever the document's content is modified by the user or if it was reverted from disk due to an external event.
 */
@property(readonly) NSDate *changeDate;

/*!
 @abstract A token representing the latest state of the document.
 @discussion Will change whenever the document is modified or persisted. Thus, it can be used to identify persisted versions of the document as well as in-memory versions. Tokens can be compared using -isEqual:. They also implement NSCoding and NSCopying.
 */
@property(readonly) id changeToken;

/*!
 @abstract Generates a change token for an arbitrary document persisted at the passed URL.
 @discussion The information is retrieved without file coordination. 
 */
+ (id)changeTokenForItemAtURL:(NSURL *)documentURL;


#pragma mark - Conflict managment

/*!
 @abstract The current file versions of the document.
 */
@property(readonly) NSFileVersion *currentVersion;

/*!
 @abstract Contains all currently conflicting versions (NSFileVersion) of the document.
 */
@property(readonly) NSArray *conflictVersions;

@end
