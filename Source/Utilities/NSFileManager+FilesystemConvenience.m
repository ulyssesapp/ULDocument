//
//	NSFileManager+FilesystemConvenience.m
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

#import "NSFileManager+FilesystemConvenience.h"

#import "NSURL+PathUtilities.h"

@implementation NSFileManager (FilesystemConvenience)

- (BOOL)ul_moveItemCaseSensistiveAtURL:(NSURL *)itemURL toURL:(NSURL *)dstURL error:(NSError **)error
{
	// If the file is just renamed: perform a system rename, since this is safe against case sensitivity issues...
	if ([itemURL.URLByDeletingLastPathComponent ul_isEqualToFileURL:dstURL.URLByDeletingLastPathComponent]) {
		if (rename([itemURL.path cStringUsingEncoding: NSUTF8StringEncoding], [dstURL.path cStringUsingEncoding: NSUTF8StringEncoding])) {
			if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
			return NO;
		}
		
		return YES;
	}

	return [self moveItemAtURL:itemURL toURL:dstURL error:error];
}

@end
