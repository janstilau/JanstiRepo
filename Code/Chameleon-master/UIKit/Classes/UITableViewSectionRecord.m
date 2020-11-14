#import "UITableViewSectionRecord.h"
#import "UIView.h"

@implementation UITableViewSectionRecord

- (CGFloat)sectionHeight
{
    return self.rowsTotalHeight + self.headerHeight + self.footerHeight;
}

- (void)setNumberOfRows:(NSInteger)rows withHeights:(CGFloat *)newRowHeights
{
    _rowHeightArray = realloc(_rowHeightArray, sizeof(CGFloat) * rows);
    memcpy(_rowHeightArray, newRowHeights, sizeof(CGFloat) * rows);
    _numberOfRows = rows;
}

- (void)dealloc
{
    if (_rowHeightArray) free(_rowHeightArray);
}
@end
