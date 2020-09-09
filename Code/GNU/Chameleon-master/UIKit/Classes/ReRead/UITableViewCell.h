#import "UIView.h"

// 根据 UITableViewCellAccessoryType 的不同, cell 右方有不同的图标. 一般没人用, 都自定义 cell.
typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
    UITableViewCellAccessoryNone,
    UITableViewCellAccessoryDisclosureIndicator,
    UITableViewCellAccessoryDetailDisclosureButton,
    UITableViewCellAccessoryCheckmark
};

// Cell 的下划线的样式, 根据不同的取值, 绘制不同的展示.
typedef NS_ENUM(NSInteger, UITableViewCellSeparatorStyle) {
    UITableViewCellSeparatorStyleNone,
    UITableViewCellSeparatorStyleSingleLine,
    UITableViewCellSeparatorStyleSingleLineEtched
};

// 根据 UITableViewCellStyle 不同, cell 添加不同的子控件, 一般没人用.
typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
    UITableViewCellStyleDefault,
    UITableViewCellStyleValue1,
    UITableViewCellStyleValue2,
    UITableViewCellStyleSubtitle
};

typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) {
    UITableViewCellSelectionStyleNone,
    UITableViewCellSelectionStyleBlue,
    UITableViewCellSelectionStyleGray
};

typedef NS_ENUM(NSInteger, UITableViewCellEditingStyle) {
    UITableViewCellEditingStyleNone,
    UITableViewCellEditingStyleDelete,
    UITableViewCellEditingStyleInsert
};

@class UILabel, UIImageView;

@interface UITableViewCell : UIView
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)prepareForReuse;

@property (nonatomic, readonly, strong) UIView *contentView;
@property (nonatomic, readonly, strong) UILabel *textLabel;
@property (nonatomic, readonly, strong) UILabel *detailTextLabel;
@property (nonatomic, readonly, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *selectedBackgroundView;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic) NSInteger indentationLevel;
@property (nonatomic) UITableViewCellAccessoryType accessoryType;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic) UITableViewCellAccessoryType editingAccessoryType;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isEditing) BOOL editing; // not yet implemented
@property (nonatomic, readonly) BOOL showingDeleteConfirmation;  // not yet implemented
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, assign) CGFloat indentationWidth; // 10 per default
@end
