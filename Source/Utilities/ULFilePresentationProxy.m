//
//	ULFilePresentationProxy.m
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

#import "ULFilePresentationProxy.h"
#import "ULWeakify.h"

@interface ULFilePresentationProxy ()
{
	NSOperationQueue			*_queue;
	NSURL						*_url;
	
	id			_deactivationHandler;
	id			_activationHandler;
}

@end

@implementation ULFilePresentationProxy

- (instancetype)initWithOwner:(id<ULFilePresentationProxyOwner>)owner
{
	NSParameterAssert(owner);
	
	self = [super init];
	
	if (self) {
		_owner = owner;
		_queue = [NSOperationQueue new];
		_queue.maxConcurrentOperationCount = 1;
	}
	
	return self;
}


#pragma mark - Owner management

- (void)beginPresentationOnURL:(NSURL *)url
{
	NSAssert(!_url, @"Presenter already initialized.");
	
	_url = url;
	[NSFileCoordinator addFilePresenter: self];
	
#if TARGET_OS_IPHONE
	[self setUpBackgroundHandling];
#endif
}

- (void)endPresentation
{
	if (_deactivationHandler)
		[NSNotificationCenter.defaultCenter removeObserver: _deactivationHandler];
	if (_activationHandler)
		[NSNotificationCenter.defaultCenter removeObserver: _activationHandler];
	
	_owner = nil;
	[NSFileCoordinator removeFilePresenter: self];
}

#if TARGET_OS_IPHONE
- (void)setUpBackgroundHandling
{
	// When entering background: Unregister presenter to prevent lockups with other apps
	ULWeakifySelf
	_deactivationHandler = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
		ULStrongifySelfOrReturn
		[NSFileCoordinator removeFilePresenter: self];
	}];
	
	// When entering foreground: Re-register presenter and notify about potentially missed changes
	_activationHandler = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
		ULStrongifySelfOrReturn
		
		[NSFileCoordinator addFilePresenter: self];
		
		// Notify about potentially missed changes
		[self->_queue addOperationWithBlock:^{
			ULStrongifySelfOrReturn
			[self->_owner filePresentationProxyDidRestartPresentation: self];
		}];
	}];
}
#endif


#pragma mark - Presenter properties

- (NSOperationQueue *)presentedItemOperationQueue
{
	return _queue;
}

- (NSURL *)presentedItemURL
{
	return _url;
}


#pragma mark - Item handler

- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *))completionHandler
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(accommodatePresentedItemDeletionWithCompletionHandler:)])
		[owner accommodatePresentedItemDeletionWithCompletionHandler: completionHandler];
	else
		completionHandler(NULL);
}

- (void)presentedItemDidMoveToURL:(NSURL *)newURL
{
	@autoreleasepool {
		__block id owner = _owner;
	
		if (owner && [owner respondsToSelector: @selector(presentedItemDidMoveToURL:)])
			[owner presentedItemDidMoveToURL: newURL];
	}
	
	// File presenters will stop to receive subitem notifications after moving the item. So we need to re-register presenters here.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self willChangeValueForKey: @"presentedItemURL"];
		
		[[[NSFileCoordinator alloc] initWithFilePresenter: self] coordinateReadingItemAtURL:newURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
			id owner = self->_owner;
			if (!owner)
				return;
			
			[NSFileCoordinator removeFilePresenter: self];
			self->_url = newURL;
			[NSFileCoordinator addFilePresenter: self];
		}];
		
		[self didChangeValueForKey: @"presentedItemURL"];
	});
}

- (void)presentedItemDidChange
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedItemDidChange)])
		[owner presentedItemDidChange];
}

- (void)relinquishPresentedItemToReader:(void (^)(void (^)(void)))reader
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(relinquishPresentedItemToReader:)])
		[owner relinquishPresentedItemToReader: reader];
	else
		reader(^{ });
}

- (void)relinquishPresentedItemToWriter:(void (^)(void (^)(void)))writer
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(relinquishPresentedItemToWriter:)])
		[owner relinquishPresentedItemToWriter: writer];
	else
		writer(^{ });
}

- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError *))completionHandler
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(savePresentedItemChangesWithCompletionHandler:)])
		[owner savePresentedItemChangesWithCompletionHandler:completionHandler];
	else
		completionHandler(NULL);
}

- (void)presentedItemDidGainVersion:(NSFileVersion *)version
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedItemDidGainVersion:)])
		[owner presentedItemDidGainVersion: version];
}

- (void)presentedItemDidLoseVersion:(NSFileVersion *)version
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedItemDidLoseVersion:)])
		[owner presentedItemDidLoseVersion: version];
}

- (void)presentedItemDidResolveConflictVersion:(NSFileVersion *)version
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedItemDidResolveConflictVersion:)])
		[owner presentedItemDidResolveConflictVersion: version];
}


#pragma mark - Subitem notifications

- (void)accommodatePresentedSubitemDeletionAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(accommodatePresentedSubitemDeletionAtURL:completionHandler:)])
		[owner accommodatePresentedSubitemDeletionAtURL:url completionHandler:completionHandler];
	else
		completionHandler(NULL);
	
}

- (void)presentedSubitemDidAppearAtURL:(NSURL *)url
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemDidAppearAtURL:)])
		[owner presentedSubitemDidAppearAtURL: url];
}

- (void)presentedSubitemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemAtURL:didMoveToURL:)])
		[owner presentedSubitemAtURL:oldURL didMoveToURL:newURL];
}

- (void)presentedSubitemDidChangeAtURL:(NSURL *)url
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemDidChangeAtURL:)])
		[owner presentedSubitemDidChangeAtURL: url];
	
	// We may need to forward to presentedItemDidChange. Otherwise it won't be triggered, because the proxy already handled -presentedSubitemDidChange (see NSFilePresenter documentation).
	else if (owner && [owner respondsToSelector: @selector(presentedItemDidChange)])
		[owner presentedItemDidChange];
}

- (void)presentedSubitemAtURL:(NSURL *)url didGainVersion:(NSFileVersion *)version
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemAtURL:didGainVersion:)])
		[owner presentedSubitemAtURL:url didGainVersion:version];
}

- (void)presentedSubitemAtURL:(NSURL *)url didLoseVersion:(NSFileVersion *)version
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemAtURL:didLoseVersion:)])
		[owner presentedSubitemAtURL:url didLoseVersion:version];
}

- (void)presentedSubitemAtURL:(NSURL *)url didResolveConflictVersion:(NSFileVersion *)version;
{
	id owner = _owner;
	
	if (owner && [owner respondsToSelector: @selector(presentedSubitemAtURL:didResolveConflictVersion:)])
		[owner presentedSubitemAtURL:url didResolveConflictVersion:version];
}

@end
