//
//	NSFileCoordinator+Convenience.h
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

/*!
 @abstract Helper methods and workarounds for common issues with NSFileCoordinator
 */
@interface NSFileCoordinator (Convenience)

/*!
 @abstract Coordinates a rename operation of a filename while keeping the case of a filename intact.
 @discussion The caller needs to notify the file coordinator using -itemAtURL:didMoveToURL: before completing the block.
 */
- (BOOL)ul_coordinateMovingItemAtURL:(NSURL *)url toURL:(NSURL *)newURL error:(NSError **)outError byAccessor:(void (^)(NSURL *oldURL, NSURL *newURL))writer;

@end
