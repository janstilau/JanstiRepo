#ifndef __FoundationErrors_h_GNUSTEP_BASE_INCLUDE
#define __FoundationErrors_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

/* These are those of the NSError code values for the NSCocoaErrorDomain
 * which are defined in the foundation/base library.
 */

enum
{

  NSFileErrorMaximum = 1023,
  NSFileErrorMinimum = 0,
  NSFileLockingError = 255,
  NSFileNoSuchFileError = 4,
  NSFileReadCorruptFileError = 259,
  NSFileReadInapplicableStringEncodingError = 261,
  NSFileReadInvalidFileNameError = 258,
  NSFileReadNoPermissionError = 257,
  NSFileReadNoSuchFileError = 260,
  NSFileReadUnknownError = 256,
  NSFileReadUnsupportedSchemeError = 262,
  NSFileWriteInapplicableStringEncodingError = 517,
  NSFileWriteInvalidFileNameError = 514,
  NSFileWriteFileExistsError = 516,
  NSFileWriteNoPermissionError = 513,
  NSFileWriteOutOfSpaceError = 640,
  NSFileWriteUnknownError = 512,
  NSFileWriteUnsupportedSchemeError = 518,
  NSFormattingError = 2048,
  NSFormattingErrorMaximum = 2559,
  NSFormattingErrorMinimum = 2048,
  NSKeyValueValidationError = 1024,
  NSUserCancelledError = 3072,
  NSValidationErrorMaximum = 2047,
  NSValidationErrorMinimum = 1024,

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
  NSExecutableArchitectureMismatchError = 3585,
  NSExecutableErrorMaximum = 3839,
  NSExecutableErrorMinimum = 3584,
  NSExecutableLinkError = 3588,
  NSExecutableLoadError = 3587,
  NSExecutableNotLoadableError = 3584,
  NSExecutableRuntimeMismatchError = 3586,
  NSFileReadTooLargeError = 263,
  NSFileReadUnknownStringEncodingError = 264,
#endif

  GSFoundationPlaceHolderError = 9999
};

#endif
#endif

