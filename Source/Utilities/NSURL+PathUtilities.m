//
//	NSURL+PathUtilities.m
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

#import "NSURL+PathUtilities.h"

#import <objc/runtime.h>

void *NSURLCachedIsCaseSensitiveFileURLKey	= "NSURLCachedIsCaseSensitiveFileURLKey";
void *NSURLCachedStandardizedPathKey		= "NSURLCachedStandardizedPathKey";

@implementation NSURL (PathUtilities)

- (BOOL)ul_isCaseSensitiveFileURL
{
#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
	return YES;
#else
	// Prefer cached value if possible
	NSNumber *isCaseSensitive = objc_getAssociatedObject(self, NSURLCachedIsCaseSensitiveFileURLKey);
	if (isCaseSensitive)
		return isCaseSensitive.boolValue;
	
	
	// Retrieve value from disk
	NSURL *referenceURL = self;
	
	while (referenceURL.path.length) {
		BOOL success = [referenceURL getResourceValue:&isCaseSensitive forKey:NSURLVolumeSupportsCaseSensitiveNamesKey error:NULL];
		if (success)
			break;
	
		// URL does not exist, try to find existing parent to get the required information. Otherwise we may provide invalid case information for a URL pointing to a not-existing file.
		referenceURL = referenceURL.URLByDeletingLastPathComponent;
	}
	
	objc_setAssociatedObject(self, NSURLCachedIsCaseSensitiveFileURLKey, isCaseSensitive, OBJC_ASSOCIATION_RETAIN);
	return isCaseSensitive.boolValue;
#endif
}

- (NSURL *)ul_URLByFastStandardizingPath
{
	NSString *cachedStandardizedPath = self.ul_cachedStandardizedPath;
	
	NSURL *url = [NSURL fileURLWithPath: cachedStandardizedPath];
	objc_setAssociatedObject(url, NSURLCachedStandardizedPathKey, cachedStandardizedPath, OBJC_ASSOCIATION_RETAIN);
	
	return url;
}

- (NSString *)ul_cachedStandardizedPath
{
	// Use cached standardized path
	NSString *standardizedPath = objc_getAssociatedObject(self, NSURLCachedStandardizedPathKey);
	if (standardizedPath)
		return standardizedPath;
	
	NSAssert(self.isFileURL, @"Cannot standardize non-file URLs");
	NSString *path = self.URLByStandardizingPath.path;
	
	// In contrast to URLByStandardizing path, remove "/private" prefix also for non-existing pathes (required for files that have not been downloaded yet).
	if ([path hasPrefix: @"/private/var/"])
		path = [path substringFromIndex: @"/private".length];
	
	// Try to cache standardized path
	objc_setAssociatedObject(self, NSURLCachedStandardizedPathKey, path, OBJC_ASSOCIATION_RETAIN);
	return path;
}

- (BOOL)ul_isEqualToFileURL:(NSURL *)otherURL
{
	NSParameterAssert(self.isFileURL);
	if (!otherURL)
		return NO;
	
	// Use case-sensitive compare if at least one URL is on a case-sensitive FS
	NSStringCompareOptions compareOption = self.ul_isCaseSensitiveFileURL ? 0 : NSCaseInsensitiveSearch;
	return ([self.ul_cachedStandardizedPath compare:otherURL.ul_cachedStandardizedPath options:compareOption] == NSOrderedSame);
}

- (NSURL *)ul_URLByResolvingExactFilenames
{
	NSParameterAssert(self.isFileURL);
	
	// Skip on case-sensistive FS
	if (self.ul_isCaseSensitiveFileURL)
		return self.ul_URLByFastStandardizingPath;
	
	// Need to re-instantiate URL to clean any stale URL caches and bookmark data
	NSDictionary *pathInfo = [[NSURL fileURLWithPath: self.path] resourceValuesForKeys:@[NSURLParentDirectoryURLKey, NSURLNameKey] error:NULL];
	if (pathInfo.count != 2)
		return self;
	
	// Build path from properties with correct casing and standardize again, since NSURLParentDirectoryURLKey may not provide a standardized path...
	return [[pathInfo[NSURLParentDirectoryURLKey] URLByAppendingPathComponent:pathInfo[NSURLNameKey]] ul_URLByFastStandardizingPath];
}


#pragma mark - URL cache surpassing

- (NSDictionary *)ul_uncachedResourceValuesForKeys:(NSArray *)keys error:(NSError **)outError
{
#if !TARGET_OS_IPHONE
	if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8) {
#endif
		CFURLRef cfURL = (__bridge CFURLRef)self;
		
		for (NSString *key in keys) {
			CFURLClearResourcePropertyCacheForKey(cfURL, (__bridge CFStringRef)key);
		}

		CFErrorRef cfError = NULL;
		NSDictionary *values = CFBridgingRelease(CFURLCopyResourcePropertiesForKeys(cfURL, (__bridge CFArrayRef)keys, &cfError));
		
		if (outError) *outError = CFBridgingRelease(cfError);
		return values;
#if !TARGET_OS_IPHONE
	}
	else {
		for (NSString *key in keys)
			[self removeCachedResourceValueForKey: key];
		
		return [self resourceValuesForKeys:keys error:outError];
	}
#endif
}

- (id)ul_uncachedResourceValueForKey:(NSString *)key error:(NSError **)error
{
	return [self ul_uncachedResourceValuesForKeys:@[key] error:error][key];
}


#pragma mark - Attribute access

- (NSDate *)ul_fileCreationDate
{
	// We may not flush the URL cache, since NSFileVersion seems to rely on exact instances somehow (ULDocumentTest -testVersionAutocreation will fail)
	return [self resourceValuesForKeys:@[NSURLCreationDateKey] error:NULL][NSURLCreationDateKey];
}

- (NSDate *)ul_fileModificationDate
{
	return [self ul_uncachedResourceValueForKey:NSURLContentModificationDateKey error:NULL];
}

- (id)ul_generationIdentifier
{
	return [self ul_uncachedResourceValueForKey:NSURLGenerationIdentifierKey error:NULL] ?: @(self.ul_fileModificationDate.timeIntervalSinceReferenceDate);
}

- (NSDictionary *)ul_preservableFileAttributes
{
	// We may not flush the URL cache, since NSFileVersion seems to rely on exact instances somehow (ULDocumentTest -testVersionAutocreation will fail)
	return [self resourceValuesForKeys:@[NSURLCreationDateKey] error:NULL];
}

- (BOOL)ul_isUbiquitousItem
{
	return [[self resourceValuesForKeys:@[NSURLIsUbiquitousItemKey] error:NULL][NSURLIsUbiquitousItemKey] boolValue];
}

@end
