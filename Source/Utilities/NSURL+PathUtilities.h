//
//	NSURL+PathUtilities.h
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

@interface NSURL (PathUtilities)

/*!
 @abstract Compares the standardized paths of two URLs. Uses the correct case-sensitivity option depending on the file system of the URL.
 @discussion Compares URLs in a standardized manner. For performance reason, the URL should be created by URLByFastStandardizingPath if multiple comparison are to be expected. It is not required that the URL references an existing file.
 */
- (BOOL)isEqualToFileURL:(NSURL *)otherURL;


#pragma mark - Fast URL standardizing

/*!
 @abstract Creates a standardized variant of an URL that uses the exact filename casing stored on disk.
 */
- (NSURL *)URLByResolvingExactFilenames;

/*!
 @abstract Creates a standardized variant of an URL.
 @discussion To improve standardization performance, this method will mark the URL as standardized for its entire lifetime. Further standardization will thus result in the same path.
 */
- (NSURL *)URLByFastStandardizingPath;


#pragma mark - URL cache surpassing

/*!
 @abstract Provides access to the given resource values by surpassing the URL cache.
 */
- (NSDictionary *)uncachedResourceValuesForKeys:(NSArray *)keys error:(NSError **)error;

/*!
 @abstract Provides access to the given resource value by surpassing the URL cache.
 */
- (id)uncachedResourceValueForKey:(NSString *)key error:(NSError **)error;


#pragma mark - Attribute queries

/*!
 @abstract Provides the most recent file modification date.
 @discussion This method ensures to provide the most recent date by surpassing the URL resource value cache.
 */
- (NSDate *)fileModificationDate;

/*!
 @abstract Provides a dictionary with URL properties that should be preserved when rewriting, moving or copying a file.
 @discussion Currently, this is only the file creation date.
 */
- (NSDictionary *)preservableFileAttributes;

@end
