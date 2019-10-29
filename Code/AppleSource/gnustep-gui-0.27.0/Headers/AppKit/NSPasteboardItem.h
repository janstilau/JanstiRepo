#ifndef _GNUstep_H_NSPasteboardItem
#define _GNUstep_H_NSPasteboardItem 
#import <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSObject.h>
#import <AppKit/AppKitDefines.h>
#import <AppKit/NSPasteboard.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)

@class NSArray;
@class NSData;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@protocol NSPasteboardItemDataProvider;

@interface NSPasteboardItem : NSObject <NSPasteboardWriting, NSPasteboardReading> {
  NSMutableDictionary *_providerMap;
  NSMutableDictionary *_dataMap;
  NSMutableArray *_types;
}
#if GS_HAS_DECLARED_PROPERTIES
@property (readonly, copy) NSArray *types;
#else
- (NSArray *)types;
#endif

- (NSString *)availableTypeFromArray:(NSArray *)types;
- (BOOL)setDataProvider:(id<NSPasteboardItemDataProvider>)dataProvider
               forTypes:(NSArray *)types;
- (BOOL)setData:(NSData *)data forType:(NSString *)type;
- (BOOL)setString:(NSString *)string forType:(NSString *)type;
- (BOOL)setPropertyList:(id)propertyList forType:(NSString *)type;

- (NSData *)dataForType:(NSString *)type;
- (NSString *)stringForType:(NSString *)type;
- (id)propertyListForType:(NSString *)type;
@end

@protocol NSPasteboardItemDataProvider <NSObject>
- (void) pasteboard: (NSPasteboard *)pasteboard
               item: (NSPasteboardItem *)item
 provideDataForType: (NSString *)type;

#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (NSPasteboardItemDataProvider)
#endif

- (void)pasteboardFinishedWithDataProvider:(NSPasteboard *)pasteboard;
@end

#endif

#endif
