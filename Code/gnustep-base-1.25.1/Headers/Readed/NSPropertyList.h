#ifndef __NSPropertyList_h_GNUSTEP_BASE_INCLUDE
#define __NSPropertyList_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

@class NSData, NSString, NSInputStream, NSOutputStream;

enum {
  NSPropertyListImmutable = 0,
  NSPropertyListMutableContainers,
  NSPropertyListMutableContainersAndLeaves // 这里, 也有这三个项, 和 json 中一样, 都是在返回数据的时候, 表示要生成什么样的容器类. 比如在看到 dict 这个标签的时候, 当然, 解析的过程中铁定是 NSMutableDict, 而这个NSMutableDict 在最后返回的时候, 一般会进行一次 copy 操作.
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
 * formats.  A property list is roughly an [NSArray] or [NSDictionary] object,
 * with these or [NSNumber], [NSData], [NSString], or [NSDate] objects
 * as members.  (See below.)</p>
 
 为什么, 是几个这几个呢, 因为无论多复杂的数据, 都可以通过上面的方式, 变成 propertyList. proeprtyList 本质上来说, 不过是一个变种的XML 文件而已, 这个变种是, 限制了节点的类型和节点的含义. 限制节点的类型指的是 ,只有 dcit, array, number, data string, date. 节点的含义指的是, 在这几个有限的类型下面, 按照到类型规定的方式去读取节点. 例如, array 就是一组数据, dict 就是 key, value 这猴子那个形式.
 因为 所有的对象数据, 都可以通过, 1 字典进行管理, 2 数组去表示一种很特殊的数据结构, 就是相似, 有序的数据. 3 字符串可以对大部分类型的数据进行描述 4 数字可以对于大部分数值可以表示的类型进行标书. 5 Date 本身可以用时间戳表示, 但是 proeprtyList 为了阅读的方便, 用了一种更加对于阅读者友好的方式进行了展示.
 
 
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
 *     <example>
 *       &lt;array&gt;&lt;string&gt;one&lt;/string&gt;&lt;string&gt;two&lt;/string&gt;&lt;string&gt;three&lt;/string&gt;&lt;/array&gt;
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

#if	defined(__cplusplus)
}
#endif

#endif	/* __NSPropertyList_h_GNUSTEP_BASE_INCLUDE*/
