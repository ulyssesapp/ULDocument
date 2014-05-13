# ULDocument
This repository contains `ULDocument`, an abstract document class designed as a lightweight alternative to NSDocument and UIDocument. It is used inside our applications [Ulysses](http://www.ulyssesapp.com) and [Daedalus](http://www.daedalusapp.com).

The benefits of `ULDocument` are:

- It is a pure model class without any dependencies to the view or controller layer.

- It has been designed for shoeboxed applications that need to present dozens of document instances at once. 

- It is ready for iCloud.

- It works on OS X and iOS.

## Getting started 
This repository is available as CocoaPod: `ULDocument`. 

Alternatively, you can clone this repository and compile ULDocument as library. You can link this library into your OS X or iOS project. You’ll find all required header files inside the folder `Header`. It also contains a small unit test suite.

## Your own ULDocument subclass
`ULDocument` is an abstract class. To use it inside your application you need to create your own subclass of it. The header `ULDocument_Subclassing.h` contains all methods that are useful hooks or helper for subclassing. Typically, it is completely sufficient to implement the following abstract methods for reading and writing your document:

	- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper error:(NSError **)outError;

	- (NSFileWrapper *)fileWrapperWithError:(NSError **)outError;

Your implementation of `-readFromFileWrapper:` should store the read contents into a property of your subclass. For example, a text document should have a property `text` that will be set when reading the document. This property is typically a mutable object bound to your document editor view. Your document subclass must observe changes on this property and should call `-updateChangeDate` whenever changes has been observed. To support autosaving and undoing, any document editor must also make use the [`undoManager`](https://developer.apple.com/library/mac/documentation/cocoa/reference/foundation/Classes/NSUndoManager_Class/Reference/Reference.html) provided by your document instance. 

All magic required for iCloud is already implemented inside ULDocument: It automatically updates a document’s contents if external changes occur and correctly synchronizes your file accesses. So, it is just sufficient to store your document inside the [ubiquity container](https://developer.apple.com/library/ios/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html#//apple_ref/doc/uid/TP40012094-CH2-SW1) of your application.

## Using ULDocument
You create a new instance of your document subclass using: `-initWithFileURL:readOnly:`. Usually, you may set `readOnly` to `NO`. However, for performance reasons you should consider to open documents in read-only mode whenever it is sufficient.

After initializing the document instance, you can open and read its contents asynchronously using `-openWithCompletionHandler:`. To save any changes just use `-saveWithCompletionHandler:`. You may use `-saveToURL:forSaveOperation:completionHandler:` to explicitly store a document on a new URL.

If a document is no longer needed, you should close it by using `-closeWithCompletionHandler:`. Any unsaved changes will be automatically persisted.

## Using KVO on ULDocument
Since ULDocument embraces the NSFileCoordinator APIs of OS X and iOS, it may manipulate any properties on an arbitrary background thread. Whenever you’re observing properties of ULDocument from a view, you may need to dispatch the observation handler on main queue. 

Generally, you should handle any observations asynchronously to prevent deadlocks: ULDocument uses locks to synchronize file and property accesses very extensively.
