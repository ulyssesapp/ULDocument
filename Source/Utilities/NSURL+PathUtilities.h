//
//	NSURL+PathUtilities.h
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

@interface NSURL (PathUtilities)

/*!
 @abstract Compares the standardized paths of two URLs. Uses the correct case-sensitivity option depending on the file system of the URL.
 @discussion Compares URLs in a standardized manner. For performance reason, the URL should be created by ul_URLByFastStandardizingPath if multiple comparison are to be expected. It is not required that the URL references an existing file.
 */
- (BOOL)ul_isEqualToFileURL:(NSURL *)otherURL;


#pragma mark - Fast URL standardizing

/*!
 @abstract Creates a standardized variant of an URL that uses the exact filename casing stored on disk.
 */
- (NSURL *)ul_URLByResolvingExactFilenames;

/*!
 @abstract Creates a standardized variant of an URL.
 @discussion To improve standardization performance, this method will mark the URL as standardized for its entire lifetime. Further standardization will thus result in the same path.
 */
- (NSURL *)ul_URLByFastStandardizingPath;


#pragma mark - URL cache surpassing

/*!
 @abstract Provides access to the given resource values by surpassing the URL cache.
 */
- (NSDictionary *)ul_uncachedResourceValuesForKeys:(NSArray *)keys error:(NSError **)error;

/*!
 @abstract Provides access to the given resource value by surpassing the URL cache.
 */
- (id)ul_uncachedResourceValueForKey:(NSString *)key error:(NSError **)error;


#pragma mark - Attribute queries

/*!
 @abstract Provides the file creation date.
 */
- (NSDate *)ul_fileCreationDate;

/*!
 @abstract Provides the most recent file modification date.
 @discussion This method ensures to provide the most recent date by surpassing the URL resource value cache.
 */
- (NSDate *)ul_fileModificationDate;

/*!
 @abstract Provides the most recent generation identifier.
 @discussion If the underlying filesystem doesn't support generation identifier, the last modification timestamp is returned.
 */
- (id)ul_generationIdentifier;

/*!
 @abstract Provides a dictionary with URL properties that should be preserved when rewriting, moving or copying a file.
 @discussion Currently, this is only the file creation date.
 */
- (NSDictionary *)ul_preservableFileAttributes;

/*!
 @abstract Whether the URL is stored inside an iCloud storage or not.
 */
- (BOOL)ul_isUbiquitousItem;

@end
