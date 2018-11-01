//
//  ULDocument_Subclassing.h
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
 @abstract Methods that can be or should be overriden by subclasses.
 */
@interface ULDocument ()


#pragma mark - Reading and writing content

/*!
 @abstract Read the document's contents from the specified file wrapper.
 @discussion Either this method or -readFromURL:error: must be overwritten by subclasses. Returns YES on success or NO and an error ortherwise.
 */
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper error:(NSError **)outError;

/*!
 @abstract A representation of the document's contents for writing to disk.
 @discussion Either this method or -writeToURL:forSaveOperation:originalContentsURL:error: must be overwritten by subclasses. Returns a file wrapper representation on success or NO and an error ortherwise.
 */
- (NSFileWrapper *)fileWrapperWithError:(NSError **)outError;


#pragma mark - Advanced reading and writing hooks

/*!
 @abstract Synchronously reads the document's contents from the specified URL.
 @discussion Either this method or -readFromFileWrapper:error: must be overwritten by subclassers. Returns YES on success or NO and an error ortherwise.
 */
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;

/*!
 @abstract Synchronously writes the document's contents to the specified URL.
 @discussion The write operation must be atomic. Either this method or -fileWrapperWithError: must be overwritten by subclassers. Returns YES on success or NO and an error ortherwise.
 */
- (BOOL)writeToURL:(NSURL *)url forSaveOperation:(ULDocumentSaveOperation)saveOperation originalContentsURL:(NSURL *)originalURL error:(NSError **)outError;

/*!
 @abstract Returns an array of NSURL attributes that should be considered for building change tokens.
 @discussion Default implementation just returns NSURLContentModificationDate. The returned token attributes must implement the -description method. A version identifier is passed out identifying the attribute set used for this token.
 */
+ (void)getChangeTokenURLAttributes:(NSArray **)attributes versionIdentifier:(NSString **)identifier;

/*!
 @abstract Specifies that the document should expect that package subitem changes are not notified correctly.
 @discussion Ignored for non-package files. Defaults to NO.
 */
+ (BOOL)shouldHandleSubitemChanges;


#pragma mark - Filename handling

/*!
 @abstract Provides the URL for save operations whenever an explicit filename is not given.
 @discussion Subclasses may override this method to perform additional filename sanitization. If specified, sanitization is allowed to reuse an existing filename if a filename collision occurs. Default implementation uses -preferredFilename for filename generation, regardless of existing filenames in the same folder.
 */
- (NSURL *)URLForSaveOperation:(ULDocumentSaveOperation)saveOperation ignoreCurrentName:(BOOL)ignoreCurrentName;

/*!
 @abstract Notifies the subclass that the document has been persisted to its current -fileURL.
 @discussion Will be called during file coordination and before updating the document's change token. Make sure that no expensive operation is performed at this point. Will not be called on Save To operations.
 */
- (void)didUpdatePersistentRepresentation;

/*!
 @abstract Notifies the subclass that the file URL of the document has been changed while auto-saving the document.
 @discuss Use this hook to determine active, user-driven filename changes. E.g. for updating external meta data stores. Default implementation does nothing. Please note that the renamed file is still coordinated during the method call.
 */
- (void)didChangeFileURLBySaving;

/*!
 @abstract Notifies the subclass that the file has been externally moved to another URL.
 */
- (void)didMoveToURL:(NSURL *)newURL;


#pragma mark - General document managment

/*!
 @abstract Immediatelly close the the document.
 @discussion All unsaved changes will be discarded. Subclasses should override this method to ensure the document is no longer usable.
 */
- (void)close;


#pragma mark - Editability

/*!
 @abstract Disables all user modifications.
 @discussion Should be used by subclasses to do whatever it takes to not cause changes to happen.
 */
- (void)disableEditing;

/*!
 @abstract Re-enables all user modifications.
 @discussion Allows subclasses to revert all measures to prevent the document from chaning installed in -disableEditing.
 */
- (void)enableEditing;


#pragma mark - Change managment

/*!
 @abstract The undo manager of the document.
 @discussion All changes to the document's contents should be registered with this very undo manager.
 */
@property(retain) NSUndoManager *undoManager;

/*!
 @abstract Notify the document of any changes happening.
 @discussion This method will be called automatically for any changes registered with the document's undo manager.
 */
- (void)updateChangeCount:(ULDocumentChangeKind)change;

/*!
 @abstract Update the document's change date to the current one.
 @discussion This method will be called automatically from -updateChangeCount: and thus also for any changes registered with the document's undo manager. Subclasses may still want to invoke it in order to notify observers of every change.
 */
- (void)updateChangeDate;

/*!
 @abstract End all undo coalescing if needed.
 @discussion Allows subclasses to perform measures to break any pending undo coalescings.
 */
- (void)breakUndoCoalescing;

@end
