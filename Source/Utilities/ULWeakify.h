//
//  ULWeakify.h
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

#ifndef ULWeakify_h
#define ULWeakify_h

/*!
 @abstract Convenience for constructing a temporary weak pointer inside the current scope.
 */
#define ULWeakify(__variableName)		__weak typeof(__variableName) __temp_weak_ ## __variableName = __variableName;

/*!
 @abstract Convenience for constructing a strong pointer from a temporary weak variable inside the current scope.
 @discussion The variable must have been weakified before with ULWeakify(var).
 */
#define ULStrongify(__variableName)		typeof(__variableName) __variableName = __temp_weak_ ## __variableName;

/*!
 @abstract Convenience for constructing a strong pointer from a temporary weak variable inside the current scope. If the variable is not available, the scope returns immediately.
 @discussion The variable must have been weakified before with ULWeakify(var).
 */
#define ULStrongifyOrReturn(__variableName)		ULStrongify(__variableName); if (!(__temp_weak_ ## __variableName)) return;

/*!
 @abstract Convenience for constructing a weak self pointer inside the current scope.
 */
#define ULWeakifySelf					ULWeakify(self)

/*!
 @abstract Convenience for strongifying self inside the current scope.
 */
#define ULStrongifySelf					ULStrongify(self)

/*!
 @abstract Convenience for strongifying self inside the current scope, leaving the scope if self has been lost.
 */
#define ULStrongifySelfOrReturn			ULStrongifyOrReturn(self)

#endif
