//
//	ULFilePresentationProxy.h
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
 @abstract Simple object that proxies file presentation messages.
 @discussion Use this object to avoid the owner being retained by the file coordination system. Clients must make sure the usage is ended when owner goes away!
 */
@interface ULFilePresentationProxy : NSObject <NSFilePresenter>

/*!
 @abstract Initializes the proxy for a certain object. The owner must be weakly referencable.
 @discussion The file presentation proxy is still inactive after initialization. To activate it, use -beginPresentationOnURL:.
 */
- (ULFilePresentationProxy *)initWithOwner:(id<NSFilePresenter>)owner;

/*!
 @abstract Activates the file presentation proxy on a certain URL.
 @discussion Make sure that the url is currently read-coordinated by the caller. Throws an assertion if called twice.
 */
- (void)beginPresentationOnURL:(NSURL *)url;

/*!
 @abstract Deactivates a file presentation proxy. 
 @discussion Due to technical reasons, presentation proxies cannot be deactivated automatically. Thus, this method must be called before a proxy object should be disposed.
 */
- (void)endPresentation;

/*!
 @abstract The owner of the proxy.
 */
@property(readonly, weak) id<NSFilePresenter> owner;

@end
