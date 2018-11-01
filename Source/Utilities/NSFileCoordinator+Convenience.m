//
//	NSFileCoordinator+Convenience.m
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

#import "NSFileCoordinator+Convenience.h"

#import "NSURL+PathUtilities.h"

@implementation NSFileCoordinator (Convenience)

- (BOOL)ul_coordinateMovingItemAtURL:(NSURL *)url toURL:(NSURL *)newURL error:(NSError **)outError byAccessor:(void (^)(NSURL *oldURL, NSURL *newURL))writer
{
	[self coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForMoving writingItemAtURL:newURL options:0 error:outError byAccessor:^(NSURL *oldURL, NSURL *coordinatedNewURL) {
		// New URL equivalent beside filename case: use originally passed version of new URL
		if ([coordinatedNewURL ul_isEqualToFileURL:newURL])
			writer(oldURL, newURL);
		
		// Use new URL provided by coordinator
		else
			writer(oldURL, coordinatedNewURL);
	}];
	
	return (!outError || *outError == nil);
}

@end
