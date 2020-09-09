#import "UITableView.h"
#import "UITableViewCell+UIPrivate.h"
#import "UIColor.h"
#import "UITouch.h"
#import "UITableViewSectionRecord.h"
#import "UITableViewSectionLabel.h"
#import "UIScreenAppKitIntegration.h"
#import "UIWindow.h"
#import "UIKitView.h"
#import "UIApplicationAppKitIntegration.h"
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSEvent.h>

NSString *const UITableViewIndexSearch = @"{search}";

const CGFloat _UITableViewDefaultRowHeight = 43;

@implementation UITableView {
    BOOL _needsReload;
    NSIndexPath *_selectedRow;
    NSIndexPath *_highlightedRow;
    
    NSMutableDictionary *_cachedCells;
    NSMutableSet *_reusableCells;
    
    NSMutableArray<UITableViewSectionRecord*> *_sections;
    
    // 这个库的作者, 将 delegate 的各个能力进行了存储, 减少了 respond 的调用.
    struct {
        unsigned heightForRowAtIndexPath : 1;
        unsigned heightForHeaderInSection : 1;
        unsigned heightForFooterInSection : 1;
        unsigned viewForHeaderInSection : 1;
        unsigned viewForFooterInSection : 1;
        unsigned willSelectRowAtIndexPath : 1;
        unsigned didSelectRowAtIndexPath : 1;
        unsigned willDeselectRowAtIndexPath : 1;
        unsigned didDeselectRowAtIndexPath : 1;
        unsigned willBeginEditingRowAtIndexPath : 1;
        unsigned didEndEditingRowAtIndexPath : 1;
        unsigned titleForDeleteConfirmationButtonForRowAtIndexPath: 1;
    } _delegateHas;
    
    struct {
        unsigned numberOfSectionsInTableView : 1;
        unsigned titleForHeaderInSection : 1;
        unsigned titleForFooterInSection : 1;
        unsigned commitEditingStyle : 1;
        unsigned canEditRowAtIndexPath : 1;
    } _dataSourceHas;
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame style:UITableViewStylePlain];
}

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)theStyle
{
    if ((self=[super initWithFrame:frame])) {
        _style = theStyle;
        _cachedCells = [[NSMutableDictionary alloc] init];
        _sections = [[NSMutableArray alloc] init];
        _reusableCells = [[NSMutableSet alloc] init];
        
        self.separatorColor = [UIColor colorWithRed:.88f green:.88f blue:.88f alpha:1];
        self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.showsHorizontalScrollIndicator = NO;
        self.allowsSelection = YES;
        self.allowsSelectionDuringEditing = NO;
        self.sectionHeaderHeight = self.sectionFooterHeight = 22;
        self.alwaysBounceVertical = YES;
        
        if (_style == UITableViewStylePlain) {
            self.backgroundColor = [UIColor whiteColor];
        }
        
        [self _setNeedsReload];
    }
    return self;
}

// 存储 DataSource 并且更新 dataSource 的能力
- (void)setDataSource:(id<UITableViewDataSource>)newSource
{
    _dataSource = newSource;
    
    _dataSourceHas.numberOfSectionsInTableView = [_dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)];
    _dataSourceHas.titleForHeaderInSection = [_dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)];
    _dataSourceHas.titleForFooterInSection = [_dataSource respondsToSelector:@selector(tableView:titleForFooterInSection:)];
    _dataSourceHas.commitEditingStyle = [_dataSource respondsToSelector:@selector(tableView:commitEditingStyle:forRowAtIndexPath:)];
    _dataSourceHas.canEditRowAtIndexPath = [_dataSource respondsToSelector:@selector(tableView:canEditRowAtIndexPath:)];
    
    [self _setNeedsReload];
}

// 存储 Delegate 并且更新 deleagate 的能力.
- (void)setDelegate:(id<UITableViewDelegate>)newDelegate
{
    [super setDelegate:newDelegate];
    
    _delegateHas.heightForRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)];
    _delegateHas.heightForHeaderInSection = [newDelegate respondsToSelector:@selector(tableView:heightForHeaderInSection:)];
    _delegateHas.heightForFooterInSection = [newDelegate respondsToSelector:@selector(tableView:heightForFooterInSection:)];
    _delegateHas.viewForHeaderInSection = [newDelegate respondsToSelector:@selector(tableView:viewForHeaderInSection:)];
    _delegateHas.viewForFooterInSection = [newDelegate respondsToSelector:@selector(tableView:viewForFooterInSection:)];
    _delegateHas.willSelectRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)];
    _delegateHas.didSelectRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)];
    _delegateHas.willDeselectRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:willDeselectRowAtIndexPath:)];
    _delegateHas.didDeselectRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)];
    _delegateHas.willBeginEditingRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:willBeginEditingRowAtIndexPath:)];
    _delegateHas.didEndEditingRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:didEndEditingRowAtIndexPath:)];
    _delegateHas.titleForDeleteConfirmationButtonForRowAtIndexPath = [newDelegate respondsToSelector:@selector(tableView:titleForDeleteConfirmationButtonForRowAtIndexPath:)];
}

- (void)setRowHeight:(CGFloat)newHeight
{
    _rowHeight = newHeight;
    [self setNeedsLayout];
}

/*
 在这里面, 更新一个 Section 相关的所有需要的数据
 */
- (void)_updateSectionsCache
{
    // 对于每个 section 的 header 和 footer 没有进行缓存的处理, 所以在这里进行删除操作.
    for (UITableViewSectionRecord *previousSectionRecord in _sections) {
        [previousSectionRecord.headerView removeFromSuperview];
        [previousSectionRecord.footerView removeFromSuperview];
    }
    
    // clear the previous cache
    [_sections removeAllObjects];
    
    if (_dataSource) {
        const CGFloat defaultRowHeight = _rowHeight ?: _UITableViewDefaultRowHeight;
        const NSInteger numberOfSections = [self numberOfSections];
        for (NSInteger sectionIndex=0; sectionIndex<numberOfSections; sectionIndex++) {
            // 在这里, 进行 UITableViewSection 的数据拼接.
            const NSInteger numberOfRowsInSection = [self numberOfRowsInSection:sectionIndex];
            UITableViewSectionRecord *sectionRecord = [[UITableViewSectionRecord alloc] init];
            sectionRecord.headerTitle = _dataSourceHas.titleForHeaderInSection? [self.dataSource tableView:self titleForHeaderInSection:sectionIndex] : nil;
            sectionRecord.footerTitle = _dataSourceHas.titleForFooterInSection? [self.dataSource tableView:self titleForFooterInSection:sectionIndex] : nil;
            sectionRecord.headerHeight = _delegateHas.heightForHeaderInSection? [self.delegate tableView:self heightForHeaderInSection:sectionIndex] : _sectionHeaderHeight;
            sectionRecord.footerHeight = _delegateHas.heightForFooterInSection ? [self.delegate tableView:self heightForFooterInSection:sectionIndex] : _sectionFooterHeight;
            sectionRecord.headerView = (sectionRecord.headerHeight > 0 && _delegateHas.viewForHeaderInSection)? [self.delegate tableView:self viewForHeaderInSection:sectionIndex] : nil;
            sectionRecord.footerView = (sectionRecord.footerHeight > 0 && _delegateHas.viewForFooterInSection)? [self.delegate tableView:self viewForFooterInSection:sectionIndex] : nil;
            
            // 寻找是否需要创建一个UITableViewSectionLabel作为 section 的 header 和 footer.
            if (!sectionRecord.headerView && sectionRecord.headerHeight > 0 && sectionRecord.headerTitle) {
                sectionRecord.headerView = [UITableViewSectionLabel sectionLabelWithTitle:sectionRecord.headerTitle];
            }
            if (!sectionRecord.footerView && sectionRecord.footerHeight > 0 && sectionRecord.footerTitle) {
                sectionRecord.footerView = [UITableViewSectionLabel sectionLabelWithTitle:sectionRecord.footerTitle];
            }
            
            // 在这里就添加了 section 的 header 和 footer
            if (sectionRecord.headerView) {
                [self addSubview:sectionRecord.headerView];
            } else {
                sectionRecord.headerHeight = 0;
            }
            if (sectionRecord.footerView) {
                [self addSubview:sectionRecord.footerView];
            } else {
                sectionRecord.footerHeight = 0;
            }
            
            // 在这里更新每个 row 的 height, 并且存储总的 row 的 height
            CGFloat *rowHeights = malloc(numberOfRowsInSection * sizeof(CGFloat));
            CGFloat totalRowsHeight = 0;
            for (NSInteger row=0; row<numberOfRowsInSection; row++) {
                const CGFloat rowHeight = _delegateHas.heightForRowAtIndexPath? [self.delegate tableView:self heightForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:sectionIndex]] : defaultRowHeight;
                rowHeights[row] = rowHeight;
                totalRowsHeight += rowHeight;
            }
            
            sectionRecord.rowsTotalHeight = totalRowsHeight;
            [sectionRecord setNumberOfRows:numberOfRowsInSection withHeights:rowHeights];
            free(rowHeights);
            [_sections addObject:sectionRecord];
        }
    }
}

- (void)_updateSectionsCacheIfNeeded
{
    if ([_sections count] == 0) {
        [self _updateSectionsCache];
    }
}

/*
 在这个理, 根据 section 的信息, 以及 Header, Footer 进行 scrollContentView 的更新.
 */
- (void)_setContentSize
{
    [self _updateSectionsCacheIfNeeded];
    // 根据 headerView 的高度, footerView 的高度, 以及存储的每个 section 的高度, 计算出来 contentSize
    CGFloat height = _tableHeaderView? _tableHeaderView.frame.size.height : 0;
    for (UITableViewSectionRecord *section in _sections) {
        height += [section sectionHeight];
    }
    if (_tableFooterView) {
        height += _tableFooterView.frame.size.height;
    }
    self.contentSize = CGSizeMake(0,height);
}

// 为什么说 TableView 里面 autolayout 不起作用, 就是在这里, UITableView 管理了所有的布局相关的事情.
// 这是最重要的方法, tableView 的核心所在.
// 这个方法, 在 scroll 的时候回频繁的调用, 来保持 tableView 展示的信息是准确的.
- (void)_layoutTableView
{
    const CGSize boundsSize = self.bounds.size; // tableView 的大小
    const CGFloat contentOffset = self.contentOffset.y; // tableView 的偏移量.
    const CGRect visibleBounds = CGRectMake(0,contentOffset,boundsSize.width,boundsSize.height); // 计算出真正的可视区域.
    CGFloat layoutTopLine = 0;
    
    if (_tableHeaderView) { // 在这里, 前置规定了 headerView 的 width 是 tableView 的 width. 并且规定 headerView 的 top 为 0;
        CGRect tableHeaderFrame = _tableHeaderView.frame;
        tableHeaderFrame.origin = CGPointZero;
        tableHeaderFrame.size.width = boundsSize.width;
        _tableHeaderView.frame = tableHeaderFrame;
        layoutTopLine += tableHeaderFrame.size.height;
    }
    
    // layout sections and rows
    NSMutableDictionary *availableCells = [_cachedCells mutableCopy];
    const NSInteger numberOfSections = [_sections count];
    [_cachedCells removeAllObjects];
    
    for (NSInteger section=0; section<numberOfSections; section++) {
        CGRect sectionRect = [self rectForSection:section]; // 拿到 section 的 frame 的信息.
        layoutTopLine += sectionRect.size.height;
        if (CGRectIntersectsRect(sectionRect, visibleBounds)) { // 如果, section的区域和可见区域有重叠, 才会进行绘制.
            UITableViewSectionRecord *sectionRecord = [_sections objectAtIndex:section];
            const CGRect headerRect = [self rectForHeaderInSection:section];
            const CGRect footerRect = [self rectForFooterInSection:section];
            if (sectionRecord.headerView) {
                sectionRecord.headerView.frame = headerRect;
            }
            if (sectionRecord.footerView) {
                sectionRecord.footerView.frame = footerRect;
            }
            // 之前, 仅仅是将 sectionRecord.headerView 添加到了 tableView 上, 在这里, 才会进行位置的确认.
            const NSInteger numberOfRows = sectionRecord.numberOfRows;
            for (NSInteger row=0; row<numberOfRows; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                CGRect rowRect = [self rectForRowAtIndexPath:indexPath];
                // 如果 cell 的区域在可见判断, 在这里进行 cell 的添加操作, 并且进行位置的计算.
                if (CGRectIntersectsRect(rowRect,visibleBounds) && rowRect.size.height > 0) {
                    UITableViewCell *cell = [availableCells objectForKey:indexPath] ?: [self.dataSource tableView:self cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        [_cachedCells setObject:cell forKey:indexPath];
                        [availableCells removeObjectForKey:indexPath];
                        cell.highlighted = [_highlightedRow isEqual:indexPath];
                        cell.selected = [_selectedRow isEqual:indexPath];
                        cell.frame = rowRect; // cell 添加上去之后, 会设置位置信息.
                        cell.backgroundColor = self.backgroundColor;
                        [cell _setSeparatorStyle:_separatorStyle color:_separatorColor];
                        [self addSubview:cell];
                    }
                }
            }
        }
    }
    
    for (UITableViewCell *cell in [availableCells allValues]) {
        if (cell.reuseIdentifier) {
            [_reusableCells addObject:cell];
        } else {
            [cell removeFromSuperview];
        }
    }
    
    // non-reusable cells should end up dealloced after at this point, but reusable ones live on in _reusableCells.
    
    // now make sure that all available (but unused) reusable cells aren't on screen in the visible area.
    // this is done becaue when resizing a table view by shrinking it's height in an animation, it looks better. The reason is that
    // when an animation happens, it sets the frame to the new (shorter) size and thus recalcuates which cells should be visible.
    // If it removed all non-visible cells, then the cells on the bottom of the table view would disappear immediately but before
    // the frame of the table view has actually animated down to the new, shorter size. So the animation is jumpy/ugly because
    // the cells suddenly disappear instead of seemingly animating down and out of view like they should. This tries to leave them
    // on screen as long as possible, but only if they don't get in the way.
    NSArray* allCachedCells = [_cachedCells allValues];
    for (UITableViewCell *cell in _reusableCells) {
        if (CGRectIntersectsRect(cell.frame,visibleBounds) && ![allCachedCells containsObject: cell]) {
            [cell removeFromSuperview];
        }
    }
    
    // 设置 footerView 的 frame
    if (_tableFooterView) {
        CGRect tableFooterFrame = _tableFooterView.frame;
        tableFooterFrame.origin = CGPointMake(0,layoutTopLine);
        tableFooterFrame.size.width = boundsSize.width;
        _tableFooterView.frame = tableFooterFrame;
    }
}

- (CGRect)_CGRectFromVerticalOffset:(CGFloat)offset height:(CGFloat)height
{
    return CGRectMake(0,
                      offset,
                      self.bounds.size.width,
                      height);
}

- (CGFloat)_offsetForSection:(NSInteger)index
{
    CGFloat offset = _tableHeaderView? _tableHeaderView.frame.size.height : 0;
    
    for (NSInteger s=0; s<index; s++) {
        offset += [[_sections objectAtIndex:s] sectionHeight];
    }
    
    return offset;
}

- (CGRect)rectForSection:(NSInteger)section
{
    [self _updateSectionsCacheIfNeeded];
    CGFloat sectionHeight = [[_sections objectAtIndex:section] sectionHeight];
    CGFloat sectionTop = [self _offsetForSection:section];
    return [self _CGRectFromVerticalOffset:sectionTop height:sectionHeight];
}

- (CGRect)rectForHeaderInSection:(NSInteger)section
{
    [self _updateSectionsCacheIfNeeded];
    return [self _CGRectFromVerticalOffset:[self _offsetForSection:section] height:[[_sections objectAtIndex:section] headerHeight]];
}

- (CGRect)rectForFooterInSection:(NSInteger)section
{
    [self _updateSectionsCacheIfNeeded];
    UITableViewSectionRecord *sectionRecord = [_sections objectAtIndex:section];
    CGFloat offset = [self _offsetForSection:section];
    offset += sectionRecord.headerHeight;
    offset += sectionRecord.rowsTotalHeight;
    return [self _CGRectFromVerticalOffset:offset height:sectionRecord.footerHeight];
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self _updateSectionsCacheIfNeeded];
    
    if (indexPath && indexPath.section < [_sections count]) {
        UITableViewSectionRecord *sectionRecord = [_sections objectAtIndex:indexPath.section];
        const NSUInteger row = indexPath.row;
        
        if (row < sectionRecord.numberOfRows) {
            CGFloat *rowHeights = sectionRecord.rowHeightArray;
            CGFloat offset = [self _offsetForSection:indexPath.section];
            
            offset += sectionRecord.headerHeight;
            
            for (NSInteger currentRow=0; currentRow<row; currentRow++) {
                offset += rowHeights[currentRow];
            }
            
            return [self _CGRectFromVerticalOffset:offset height:rowHeights[row]];
        }
    }
    
    return CGRectZero;
}

- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // this is allowed to return nil if the cell isn't visible and is not restricted to only returning visible cells
    // so this simple call should be good enough.
    return [_cachedCells objectForKey:indexPath];
}

// 只要 section 中存储了各种高度信息, indexPath 就很容易获得.
- (NSArray *)indexPathsForRowsInRect:(CGRect)rect
{
    // This needs to return the index paths even if the cells don't exist in any caches or are not on screen
    // For now I'm assuming the cells stretch all the way across the view. It's not clear to me if the real
    // implementation gets anal about this or not (haven't tested it).
    
    [self _updateSectionsCacheIfNeeded];
    
    NSMutableArray *results = [[NSMutableArray alloc] init];
    const NSInteger numberOfSections = [_sections count];
    CGFloat offset = _tableHeaderView? _tableHeaderView.frame.size.height : 0;
    
    for (NSInteger section=0; section<numberOfSections; section++) {
        UITableViewSectionRecord *sectionRecord = [_sections objectAtIndex:section];
        CGFloat *rowHeights = sectionRecord.rowHeightArray;
        const NSInteger numberOfRows = sectionRecord.numberOfRows;
        
        offset += sectionRecord.headerHeight;
        
        if (offset + sectionRecord.rowsTotalHeight >= rect.origin.y) {
            for (NSInteger row=0; row<numberOfRows; row++) {
                const CGFloat height = rowHeights[row];
                CGRect simpleRowRect = CGRectMake(rect.origin.x, offset, rect.size.width, height);
                
                if (CGRectIntersectsRect(rect,simpleRowRect)) {
                    [results addObject:[NSIndexPath indexPathForRow:row inSection:section]];
                } else if (simpleRowRect.origin.y > rect.origin.y+rect.size.height) {
                    break;	// don't need to find anything else.. we are past the end
                }
                
                offset += height;
            }
        } else {
            offset += sectionRecord.rowsTotalHeight;
        }
        
        offset += sectionRecord.footerHeight;
    }
    
    return results;
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point
{
    NSArray *paths = [self indexPathsForRowsInRect:CGRectMake(point.x,point.y,1,1)];
    return ([paths count] > 0)? [paths objectAtIndex:0] : nil;
}

- (NSArray *)indexPathsForVisibleRows
{
    [self _layoutTableView];
    
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:[_cachedCells count]];
    const CGRect bounds = self.bounds; // 这里有问题吧, 应该是 visibleRect
    
    // Special note - it's unclear if UIKit returns these in sorted order. Because we're assuming that visibleCells returns them in order (top-bottom)
    // and visibleCells uses this method, I'm going to make the executive decision here and assume that UIKit probably does return them sorted - since
    // there's nothing warning that they aren't. :)
    
    for (NSIndexPath *indexPath in [[_cachedCells allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        if (CGRectIntersectsRect(bounds,[self rectForRowAtIndexPath:indexPath])) {
            [indexes addObject:indexPath];
        }
    }
    
    return indexes;
}

- (NSArray *)visibleCells
{
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    for (NSIndexPath *index in [self indexPathsForVisibleRows]) {
        UITableViewCell *cell = [self cellForRowAtIndexPath:index];
        if (cell) {
            [cells addObject:cell];
        }
    }
    return cells;
}

- (void)setTableHeaderView:(UIView *)newHeader
{
    if (newHeader != _tableHeaderView) {
        [_tableHeaderView removeFromSuperview];
        _tableHeaderView = newHeader;
        [self _setContentSize]; // 需要更新 contentSize
        [self addSubview:_tableHeaderView];
    }
}

- (void)setTableFooterView:(UIView *)newFooter
{
    if (newFooter != _tableFooterView) {
        [_tableFooterView removeFromSuperview];
        _tableFooterView = newFooter;
        [self _setContentSize];
        [self addSubview:_tableFooterView];
    }
}

- (void)setBackgroundView:(UIView *)backgroundView
{
    if (_backgroundView != backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        [self insertSubview:_backgroundView atIndex:0];
    }
}

- (NSInteger)numberOfSections
{
    // 如果 dataSource 不实现这个方法, 要提供一个默认的值.
    if (_dataSourceHas.numberOfSectionsInTableView) {
        return [self.dataSource numberOfSectionsInTableView:self];
    } else {
        return 1;
    }
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
    return [self.dataSource tableView:self numberOfRowsInSection:section];
}

- (void)reloadData
{
    [[_cachedCells allValues] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_reusableCells makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_reusableCells removeAllObjects];
    [_cachedCells removeAllObjects];
    
    _selectedRow = nil;
    _highlightedRow = nil;
    
    [self _updateSectionsCache]; // 更新 section 的高度信息.
    [self _setContentSize];
    
    _needsReload = NO;
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self reloadData];
}

- (void)_reloadDataIfNeeded
{
    if (_needsReload) {
        [self reloadData];
    }
}

- (void)_setNeedsReload
{
    _needsReload = YES;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    // 在这里, _backgroundView 是个自己 pinZeroEdge 的
    _backgroundView.frame = self.bounds;
    [self _reloadDataIfNeeded];
    [self _layoutTableView];
    [super layoutSubviews];
}

- (void)setFrame:(CGRect)frame
{
    const CGRect oldFrame = self.frame;
    if (!CGRectEqualToRect(oldFrame,frame)) {
        [super setFrame:frame];
        if (oldFrame.size.width != frame.size.width) {
            [self _updateSectionsCache];
        }
        [self _setContentSize];
    }
}

- (NSIndexPath *)indexPathForSelectedRow
{
    return _selectedRow;
}

- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell
{
    for (NSIndexPath *index in [_cachedCells allKeys]) {
        if ([_cachedCells objectForKey:index] == cell) {
            return index;
        }
    }
    
    return nil;
}

// tableView 记录 selected 的信息, 而不是在 cell 中.
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    if (indexPath && [indexPath isEqual:_selectedRow]) {
        [self cellForRowAtIndexPath:_selectedRow].selected = NO;
        _selectedRow = nil;
    }
}

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
    // unlike the other methods that I've tested, the real UIKit appears to call reload during selection if the table hasn't been reloaded
    // yet. other methods all appear to rebuild the section cache "on-demand" but don't do a "proper" reload. for the sake of attempting
    // to maintain a similar delegate and dataSource access pattern to the real thing, I'll do it this way here. :)
    [self _reloadDataIfNeeded];
    
    if (![_selectedRow isEqual:indexPath]) {
        [self deselectRowAtIndexPath:_selectedRow animated:animated];
        _selectedRow = indexPath;
        [self cellForRowAtIndexPath:_selectedRow].selected = YES;
    }
    
    // I did not verify if the real UIKit will still scroll the selection into view even if the selection itself doesn't change.
    // this behavior was useful for Ostrich and seems harmless enough, so leaving it like this for now.
    [self scrollToRowAtIndexPath:_selectedRow atScrollPosition:scrollPosition animated:animated];
}

- (void)_setUserSelectedRowAtIndexPath:(NSIndexPath *)rowToSelect
{
    if (_delegateHas.willSelectRowAtIndexPath) {
        rowToSelect = [self.delegate tableView:self willSelectRowAtIndexPath:rowToSelect];
    }
    
    NSIndexPath *selectedRow = [self indexPathForSelectedRow];
    
    if (selectedRow && ![selectedRow isEqual:rowToSelect]) {
        NSIndexPath *rowToDeselect = selectedRow;
        
        if (_delegateHas.willDeselectRowAtIndexPath) {
            rowToDeselect = [self.delegate tableView:self willDeselectRowAtIndexPath:rowToDeselect];
        }
        
        [self deselectRowAtIndexPath:rowToDeselect animated:NO];
        
        if (_delegateHas.didDeselectRowAtIndexPath) {
            [self.delegate tableView:self didDeselectRowAtIndexPath:rowToDeselect];
        }
    }
    
    [self selectRowAtIndexPath:rowToSelect animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    if (_delegateHas.didSelectRowAtIndexPath) {
        [self.delegate tableView:self didSelectRowAtIndexPath:rowToSelect];
    }
}

// 滑动. 根据 UITableViewScrollPosition 的不同, 要计算出不同的位置.
- (void)_scrollRectToVisible:(CGRect)aRect atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    if (!CGRectIsNull(aRect) && aRect.size.height > 0) {
        // adjust the rect based on the desired scroll position setting
        switch (scrollPosition) {
            case UITableViewScrollPositionNone:
                break;
                
            case UITableViewScrollPositionTop:
                aRect.size.height = self.bounds.size.height;
                break;
                
            case UITableViewScrollPositionMiddle:
                aRect.origin.y -= (self.bounds.size.height / 2.f) - aRect.size.height;
                aRect.size.height = self.bounds.size.height;
                break;
                
            case UITableViewScrollPositionBottom:
                aRect.origin.y -= self.bounds.size.height - aRect.size.height;
                aRect.size.height = self.bounds.size.height;
                break;
        }
        
        [self scrollRectToVisible:aRect animated:animated];
    }
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    [self _scrollRectToVisible:[self rectForRowAtIndexPath:[self indexPathForSelectedRow]] atScrollPosition:scrollPosition animated:animated];
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    [self _scrollRectToVisible:[self rectForRowAtIndexPath:indexPath] atScrollPosition:scrollPosition animated:animated];
}

// 在 _reusableCells 中查找 cell. 可能会找不到.
- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    // 更新 _reusableCells
    for (UITableViewCell *cell in _reusableCells) {
        if ([cell.reuseIdentifier isEqualToString:identifier]) {
            UITableViewCell *strongCell = cell;
            [_reusableCells removeObject:cell];
            [strongCell prepareForReuse];
            return strongCell;
        }
    }
    return nil;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    _editing = editing;
}

- (void)setEditing:(BOOL)editing
{
    [self setEditing:editing animated:NO];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    [self reloadData];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    [self reloadData];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self reloadData];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self reloadData];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

// 更新 _highlightedRow 的信息.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_highlightedRow) {
        UITouch *touch = [touches anyObject];
        const CGPoint location = [touch locationInView:self];
        
        _highlightedRow = [self indexPathForRowAtPoint:location];
        [self cellForRowAtIndexPath:_highlightedRow].highlighted = YES;
    }
    
    if (_highlightedRow) {
        [self cellForRowAtIndexPath:_highlightedRow].highlighted = NO;
        [self _setUserSelectedRowAtIndexPath:_highlightedRow];
        _highlightedRow = nil;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_highlightedRow) {
        [self cellForRowAtIndexPath:_highlightedRow].highlighted = NO;
        _highlightedRow = nil;
    }
}

- (BOOL)_canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // it's YES by default until the dataSource overrules
    return _dataSourceHas.commitEditingStyle && (!_dataSourceHas.canEditRowAtIndexPath || [_dataSource tableView:self canEditRowAtIndexPath:indexPath]);
}

- (void)_beginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self _canEditRowAtIndexPath:indexPath]) {
        self.editing = YES;
        
        if (_delegateHas.willBeginEditingRowAtIndexPath) {
            [self.delegate tableView:self willBeginEditingRowAtIndexPath:indexPath];
        }
        
        // deferring this because it presents a modal menu and that's what we do everywhere else in Chameleon
        [self performSelector:@selector(_showEditMenuForRowAtIndexPath:) withObject:indexPath afterDelay:0];
    }
}

- (void)_endEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing) {
        self.editing = NO;
        
        if (_delegateHas.didEndEditingRowAtIndexPath) {
            [self.delegate tableView:self didEndEditingRowAtIndexPath:indexPath];
        }
    }
}

// tableView 的 edit 模式, 还是要到 cell 中实现.
- (void)_showEditMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // re-checking for safety since _showEditMenuForRowAtIndexPath is deferred. this may be overly paranoid.
    if ([self _canEditRowAtIndexPath:indexPath]) {
        UITableViewCell *cell = [self cellForRowAtIndexPath:indexPath];
        NSString *menuItemTitle = nil;
        
        // fetch the title for the delete menu item
        if (_delegateHas.titleForDeleteConfirmationButtonForRowAtIndexPath) {
            menuItemTitle = [self.delegate tableView:self titleForDeleteConfirmationButtonForRowAtIndexPath:indexPath];
        }
        if ([menuItemTitle length] == 0) {
            menuItemTitle = @"Delete";
        }
        
        cell.highlighted = YES;
        
        NSMenuItem *theItem = [[NSMenuItem alloc] initWithTitle:menuItemTitle action:NULL keyEquivalent:@""];
        
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
        [menu setAutoenablesItems:NO];
        [menu setAllowsContextMenuPlugIns:NO];
        [menu addItem:theItem];
        
        // calculate the mouse's current position so we can present the menu from there since that's normal OSX behavior
        NSPoint mouseLocation = [NSEvent mouseLocation];
        CGPoint screenPoint = [self.window.screen convertPoint:NSPointToCGPoint(mouseLocation) fromScreen:nil];
        
        // modally present a menu with the single delete option on it, if it was selected, then do the delete, otherwise do nothing
        const BOOL didSelectItem = [menu popUpMenuPositioningItem:nil atLocation:NSPointFromCGPoint(screenPoint) inView:self.window.screen.UIKitView];
        
        UIApplicationInterruptTouchesInView(nil);
        
        if (didSelectItem) {
            [_dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
        }
        
        cell.highlighted = NO;
    }
    
    // all done
    [self _endEditingRowAtIndexPath:indexPath];
}


@end
