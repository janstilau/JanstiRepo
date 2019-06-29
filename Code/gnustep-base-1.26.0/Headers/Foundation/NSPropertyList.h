#ifndef __NSPropertyList_h_GNUSTEP_BASE_INCLUDE
#define __NSPropertyList_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

/**
 *
 Here is the info.plist for MoegoApp.
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 
 Above is the meta info.
For dict, the first item is key, and the next item is value. Each value can be difffercent class.
 <dict> // The top level is a dict, dict is good for portable.
     <key>CFBundleDevelopmentRegion</key> // Key
     <string>zh_CN</string> // Value
 
     <key>CFBundleDisplayName</key>
     <string>萌股</string>
 
     <key>CFBundleExecutable</key>
     <string>$(EXECUTABLE_NAME)</string>
 
     <key>CFBundleIdentifier</key>
     <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
 
     <key>CFBundleInfoDictionaryVersion</key>
     <string>6.0</string>
 
     <key>CFBundleLocalizations</key>
     <array>// Array mark it's array now, every item is in the array.
     <string>zh_CN</string>
     <string>en</string>
     </array>// The end of array
 
     <key>CFBundleName</key>
     <string>萌股</string>
 
     <key>CFBundlePackageType</key>
     <string>APPL</string>
 
     <key>CFBundleShortVersionString</key>
     <string>1.8.0</string>
 
     <key>CFBundleURLTypes</key>
     <array>
         <dict>
             <key>CFBundleTypeRole</key>
             <string>Editor</string>
             <key>CFBundleURLName</key>
             <string>app</string>
             <key>CFBundleURLSchemes</key>
             <array>
                <string>moego</string>
             </array>
         </dict>
         <dict>
             <key>CFBundleTypeRole</key>
             <string>Editor</string>
             <key>CFBundleURLName</key>
             <string>com.weibo</string>
             <key>CFBundleURLSchemes</key>
             <array>
             <string>wb2812754643</string>
             </array>
         </dict>
         <dict>
             <key>CFBundleTypeRole</key>
             <string>Editor</string>
             <key>CFBundleURLName</key>
             <string>com.wechat</string>
             <key>CFBundleURLSchemes</key>
             <array>
             <string>wx1b6ba0f7f8d66dc9</string>
             </array>
         </dict>
         <dict>
             <key>CFBundleTypeRole</key>
             <string>Editor</string>
             <key>CFBundleURLName</key>
             <string>com.qq</string>
             <key>CFBundleURLSchemes</key>
             <array>
             <string>tencent1106878573</string>
             </array>
         </dict>
         <dict>
             <key>CFBundleTypeRole</key>
             <string>Editor</string>
             <key>CFBundleURLName</key>
             <string>com.qq</string>
             <key>CFBundleURLSchemes</key>
             <array>
             <string>QQ41f9a06d</string>
             </array>
         </dict>
     </array>
 
     <key>CFBundleVersion</key>
     <string>28</string>
 
     <key>LSApplicationQueriesSchemes</key>
     <array>
         <string>wechat</string>
         <string>weixin</string>
         <string>sinaweibohd</string>
         <string>sinaweibo</string>
         <string>sinaweibosso</string>
         <string>weibosdk</string>
         <string>weibosdk2.5</string>
         <string>mqqapi</string>
         <string>mqq</string>
         <string>mqqOpensdkSSoLogin</string>
         <string>mqqconnect</string>
         <string>mqqopensdkdataline</string>
         <string>mqqopensdkgrouptribeshare</string>
         <string>mqqopensdkfriend</string>
         <string>mqqopensdkapi</string>
         <string>mqqopensdkapiV2</string>
         <string>mqqopensdkapiV3</string>
         <string>mqqopensdkapiV4</string>
         <string>mqzoneopensdk</string>
         <string>wtloginmqq</string>
         <string>wtloginmqq2</string>
         <string>mqqwpa</string>
         <string>mqzone</string>
         <string>mqzonev2</string>
         <string>mqzoneshare</string>
         <string>wtloginqzone</string>
         <string>mqzonewx</string>
         <string>mqzoneopensdkapiV2</string>
         <string>mqzoneopensdkapi19</string>
         <string>mqzoneopensdkapi</string>
         <string>mqqbrowser</string>
         <string>mttbrowser</string>
         <string>tim</string>
         <string>timapi</string>
         <string>timopensdkfriend</string>
         <string>timwpa</string>
         <string>timgamebindinggroup</string>
         <string>timapiwallet</string>
         <string>timOpensdkSSoLogin</string>
         <string>wtlogintim</string>
         <string>timopensdkgrouptribeshare</string>
         <string>timopensdkapiV4</string>
         <string>timgamebindinggroup</string>
         <string>timopensdkdataline</string>
         <string>wtlogintimV1</string>
         <string>timapiV1</string>
         <string>alipay</string>
         <string>alipayshare</string>
         <string>dingtalk</string>
         <string>dingtalk-open</string>
         <string>linkedin</string>
         <string>linkedin-sdk2</string>
         <string>linkedin-sdk</string>
         <string>laiwangsso</string>
         <string>yixin</string>
         <string>yixinopenapi</string>
         <string>instagram</string>
         <string>whatsapp</string>
         <string>line</string>
         <string>fbapi</string>
         <string>fb-messenger-api</string>
         <string>fb-messenger-share-api</string>
         <string>fbauth2</string>
         <string>fbshareextension</string>
         <string>kakaofa63a0b2356e923f3edd6512d531f546</string>
         <string>kakaokompassauth</string>
         <string>storykompassauth</string>
         <string>kakaolink</string>
         <string>kakaotalk-4.5.0</string>
         <string>kakaostory-2.9.0</string>
         <string>pinterestsdk.v1</string>
         <string>tumblr</string>
         <string>evernote</string>
         <string>en</string>
         <string>enx</string>
         <string>evernotecid</string>
         <string>evernotemsg</string>
         <string>youdaonote</string>
         <string>ynotedictfav</string>
         <string>com.youdao.note.todayViewNote</string>
         <string>ynotesharesdk</string>
         <string>gplus</string>
         <string>pocket</string>
         <string>readitlater</string>
         <string>pocket-oauth-v1</string>
         <string>fb131450656879143</string>
         <string>en-readitlater-5776</string>
         <string>com.ideashower.ReadItLaterPro3</string>
         <string>com.ideashower.ReadItLaterPro</string>
         <string>com.ideashower.ReadItLaterProAlpha</string>
         <string>com.ideashower.ReadItLaterProEnterprise</string>
         <string>vk</string>
         <string>vk-share</string>
         <string>vkauthorize</string>
         <string>twitter</string>
         <string>twitterauth</string>
     </array>
 
     <key>LSRequiresIPhoneOS</key>
     <true/>
 
     <key>MiSDKAppID</key>
     <string></string>
 
     <key>NSAppTransportSecurity</key>
     <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
     </dict>
 
     <key>NSCameraUsageDescription</key>
     <string>你可以在应用中上传、发送相机拍摄的内容</string>
 
     <key>NSContactsUsageDescription</key>
     <string>你可以看到通讯录中使用萌股的用户</string>
 
     <key>NSLocationWhenInUseUsageDescription </key>
     <string>你可以在应用中发送自己的位置，通过位置信息查找附近的人</string>
 
     <key>NSMicrophoneUsageDescription</key>
     <string>你可以在应用中上传、发送麦克风录制的语音信息</string>
 
     <key>NSPhotoLibraryAddUsageDescription</key>
     <string>你可以在应用中保存照片到相机胶卷中</string>
 
     <key>NSPhotoLibraryUsageDescription</key>
     <string>你可以在应用中上传、发送相机胶卷中的内容，或保存照片到相机胶卷中</string>
 
     <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
     <string>你可以在应用中发送自己的位置，通过位置信息查找附近的人</string>
 
     <key>NSLocationWhenInUseUsageDescription</key>
     <string>你可以在应用中发送自己的位置，通过位置信息查找附近的人</string>
 
     <key>UIAppFonts</key>
     <array>
        <string>HappyZcool.ttf</string>
     </array>
 
     <key>UIBackgroundModes</key>
     <array>
        <string>remote-notification</string>
     </array>
 
     <key>UIRequiredDeviceCapabilities</key>
     <array>
        <string>armv7</string>
     </array>
 
     <key>UIStatusBarHidden</key>
        <true/>
 
     <key>UIStatusBarStyle</key>
        <string>UIStatusBarStyleDefault</string>
 
     <key>UISupportedInterfaceOrientations</key>
     <array>
        <string>UIInterfaceOrientationPortrait</string>
     </array>
 
     <key>UIViewControllerBasedStatusBarAppearance</key>
     <false/>
 </dict>
 
 </plist>
 */

@class NSData, NSString, NSInputStream, NSOutputStream;

enum {
  NSPropertyListImmutable = 0,
  NSPropertyListMutableContainers,
  NSPropertyListMutableContainersAndLeaves
};
/**
 * Describes the mutability to use when generating objects during
 * deserialisation of a property list.
 * <list>
 * <item><strong>NSPropertyListImmutable</strong>
 * all objects in created list are immutable</item>
 * <item><strong>NSPropertyListMutableContainers</strong>
 * dictionaries, arrays, strings and data objects are mutable</item>
 * </list>
 */
typedef NSUInteger NSPropertyListMutabilityOptions;

enum {
  NSPropertyListOpenStepFormat = 1,
  NSPropertyListXMLFormat_v1_0 = 100,
  NSPropertyListBinaryFormat_v1_0 = 200,
  NSPropertyListGNUstepFormat = 1000,
  NSPropertyListGNUstepBinaryFormat
};

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST)
typedef NSUInteger NSPropertyListWriteOptions;
typedef NSUInteger NSPropertyListReadOptions;
@class NSError;
#endif

/**
 * Specifies the serialisation format for a serialised property list.
 * <list>
 * <item><strong>NSPropertyListOpenStepFormat</strong>
 * the most human-readable format</item>
 * <item><strong>NSPropertyListXMLFormat_v1_0</strong>
 * portable and readable</item>
 * <item><strong>NSPropertyListBinaryFormat_v1_0</strong>
 * the standard format on macos-x</item>
 * <item><strong>NSPropertyListGNUstepFormat</strong>
 * extension of OpenStep format</item>
 * <item><strong>NSPropertyListGNUstepBinaryFormat</strong>
 * efficient, hardware independent</item>
 * </list>
 */
typedef NSUInteger NSPropertyListFormat;

/**
 * <p>The NSPropertyListSerialization class provides facilities for
 * serialising and deserializing property list data in a number of
 * formats. Just the same as JSON.
 
 In property list only sub class value is valuable
    A property list is roughly an [NSArray] or [NSDictionary] object,
 * with these or [NSNumber], [NSData], [NSString], or [NSDate] objects
 * as members.  (See below.)</p>
 
 * <p>You do not work with instances of this class, instead you use a
 * small number of class methods to serialize and deserialize
 * property lists.
 * </p><br/>
 * A <em>property list</em> may only be one of the following classes - 
 * <deflist>
 
 
 *   <term>[NSArray]</term>
 *   <desc>
 *     An array which is either empty or contains only <em>property list</em>
 *     objects.<br />
 *     An array is delimited by round brackets and its contents are comma
 *     <em>separated</em> (there is no comma after the last array element).
 *     <example>
 *       ( "one", "two", "three" )
 *     </example>
 *     In XML format, an array is an element whose name is <code>array</code>
 *     and whose content is the array content.
       In xml, the tag name is the class.
 *     <example>
 *       <array>&lt;string&gt;one&lt;/string&gt;&lt;string&gt;two&lt;/string&gt;&lt;string&gt;three&lt;/string&gt;<array>;
 *     </example>
 *   </desc>
 
 *   <term>[NSData]</term>
 *   <desc>
 *     An array is represented as a series of pairs of hexadecimal characters
 *     (each pair representing a byte of data) enclosed in angle brackets.
 *     Spaces are ignored).
 *     <example>
 *       &lt; 54637374 696D67 &gt;
 *     </example>
 *     In XML format, a data object is an element whose name is
 *     <code>data</code> and whose content is a stream of base64 encoded bytes.
 *   </desc>
 *   <term>[NSDate]</term>
 *   <desc>
 *     Date objects were not traditionally allowed in <em>property lists</em>
 *     but were added when the XML format was introduced.  GNUstep provides
 *     an extension to the traditional <em>property list</em> format to
 *     support date objects, but older code will not read
 *     <em>property lists</em> containing this extension.<br />
 *     This format consists of an asterisk followed by the letter 'D' then a
 *     date/time in YYYY-MM-DD HH:MM:SS +/-ZZZZ format, all enclosed within
 *     angle brackets.
 *     <example>
 *       &lt;*D2002-03-22 11:30:00 +0100&gt;
 *     </example>
 *     In XML format, a date object is an element whose name is
 *     <code>date</code> and whose content is a date in the format
 *     YYYY-MM-DDTHH:MM:SSZ (or the above dfate format).
 *     <example>
 *       &lt;date&gt;2002-03-22T11:30:00Z&lt;/date&gt;
 *     </example>
 *   </desc>
 *   <term>[NSDictionary]</term>
 *   <desc>
 *     A dictionary which is either empty or contains only <em>string</em>
 *     keys and <em>property list</em> objects.<br />
 *     A dictionary is delimited by curly brackets and its contents are
 *     semicolon <em>terminated</em> (there is a semicolon after each value).
 *     Each item in the dictionary is a key/value pair with an equals sign
 *     after the key and before the value.
 *     <example>
 *       {
 *         "key1" = "value1";
 *       }
 *     </example>
 *     In XML format, a dictionary is an element whose name is
 *     <code>dictionary</code> and whose content consists of pairs of
 *     strings and other <em>property list</em> objects.
 *     <example>
 *       &lt;dictionary&gt;
 *         &lt;string&gt;key1&lt;/string&gt;
 *         &lt;string&gt;value1&lt;/string&gt;
 *       &lt;/dictionary&gt;
 *     </example>
 *   </desc>
 *   <term>[NSNumber]</term>
 *   <desc>
 *     Number objects were not traditionally allowed in <em>property lists</em>
 *     but were added when the XML format was introduced.  GNUstep provides
 *     an extension to the traditional <em>property list</em> format to
 *     support number objects, but older code will not read
 *     <em>property lists</em> containing this extension.<br />
 *     Numbers are stored in a variety of formats depending on their values.
 *     <list>
 *       <item>boolean ... either <code>&lt;*BY&gt;</code> for YES or
 *         <code>&lt;*BN&gt;</code> for NO.<br />
 *         In XML format this is either <code>&lt;true /&gt;</code> or
 *         <code>&lt;false /&gt;</code>
 *       </item>
 *       <item>integer ... <code>&lt;*INNN&gt;</code> where NNN is an
 *         integer.<br />
 *         In XML format this is <code>&lt;integer&gt;NNN&lt;integer&gt;</code>
 *       </item>
 *       <item>real ... <code>&lt;*RNNN&gt;</code> where NNN is a real
 *         number.<br />
 *         In XML format this is <code>&lt;real&gt;NNN&lt;real&gt;</code>
 *       </item>
 *     </list>
 *   </desc>
 *   <term>[NSString]</term>
 *   <desc>
 *     A string is either stored literally (if it contains no spaces or special
 *     characters), or is stored as a quoted string with special characters
 *     escaped where necessary.<br />
 *     Escape conventions are similar to those normally used in ObjectiveC
 *     programming, using a backslash followed by -
 *     <list>
 *      <item><strong>\</strong> a backslash character</item>
 *      <item><strong>"</strong> a quote character</item>
 *      <item><strong>b</strong> a backspace character</item>
 *      <item><strong>n</strong> a newline character</item>
 *      <item><strong>r</strong> a carriage return character</item>
 *      <item><strong>t</strong> a tab character</item>
 *      <item><strong>OOO</strong> (three octal digits)
 *	  an arbitrary ascii character</item>
 *      <item><strong>UXXXX</strong> (where X is a hexadecimal digit)
 *	  a an arbitrary unicode character</item>
 *     </list>
 *     <example>
 *       "hello world &amp; others"
 *     </example>
 *     In XML format, the string is simply stored in UTF8 format as the
 *     content of a <code>string</code> element, and the only character
 *     escapes  required are those used by XML such as the
 *     '&amp;lt;' markup representing a '&lt;' character.
 *     <example>
 *       &lt;string&gt;hello world &amp;amp; others&lt;/string&gt;"
 *     </example>
 *   </desc>
 * </deflist>
 */
@interface NSPropertyListSerialization : NSObject
{
}

/**
 * Creates and returns a data object containing a serialized representation
 * of plist.  The argument aFormat is used to determine the way in which the
 * data is serialised, and the anErrorString argument is a pointer in which
 * an error message is returned on failure (nil is returned on success).
 */
+ (NSData*) dataFromPropertyList: (id)aPropertyList
			  format: (NSPropertyListFormat)aFormat
		errorDescription: (NSString**)anErrorString;

/**
 * Returns a flag indicating whether it is possible to serialize aPropertyList
 * in the format aFormat.
 */
+ (BOOL) propertyList: (id)aPropertyList
     isValidForFormat: (NSPropertyListFormat)aFormat;

/**
 * Deserialises dataItem and returns the resulting property list
 * (or nil if the data does not contain a property list serialised
 * in a supported format).<br />
 * The argument anOption is used to control whether the objects making
 * up the deserialized property list are mutable or not.<br />
 * The argument aFormat is either null or a pointer to a location
 * in which the format of the serialized property list will be returned.<br />
 * Either nil or an error message will be returned in anErrorString.
 */
+ (id) propertyListFromData: (NSData*)data
	   mutabilityOption: (NSPropertyListMutabilityOptions)anOption
		     format: (NSPropertyListFormat*)aFormat
	   errorDescription: (NSString**)anErrorString;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST)
+ (NSData *) dataWithPropertyList: (id)aPropertyList
                           format: (NSPropertyListFormat)aFormat
                          options: (NSPropertyListWriteOptions)anOption
                            error: (out NSError**)error;
+ (id) propertyListWithData: (NSData*)data
                    options: (NSPropertyListReadOptions)anOption
                     format: (NSPropertyListFormat*)aFormat
                      error: (out NSError**)error;
+ (id) propertyListWithStream: (NSInputStream*)stream
                      options: (NSPropertyListReadOptions)anOption
                       format: (NSPropertyListFormat*)aFormat
                        error: (out NSError**)error;
+ (NSInteger) writePropertyList: (id)aPropertyList
                       toStream: (NSOutputStream*)stream
                         format: (NSPropertyListFormat)aFormat
                        options: (NSPropertyListWriteOptions)anOption
                          error: (out NSError**)error;
#endif

@end

#endif	/* GS_API_MACOSX */
#endif	/* __NSPropertyList_h_GNUSTEP_BASE_INCLUDE*/
