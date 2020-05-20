//
//  AFViewController.m
//  Chapter 2 Project 4
//
//  Created by Ash Furrow on 2012-12-17.
//  Copyright (c) 2012 Ash Furrow. All rights reserved.
//

#import "AFViewController.h"

#import "AFCollectionViewCell.h"

@interface AFViewController ()

@end

static NSString *CellIdentifier = @"Cell Identifier";

@implementation AFViewController
{
    //This is our model
    NSMutableArray *datesArray;
    NSDateFormatter *dateFormatter;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //instantiate our model
    datesArray = [NSMutableArray array];
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:[NSDateFormatter dateFormatFromTemplate:@"h:mm:ss a" options:0 locale:[NSLocale currentLocale]]];
    
    //configure our collection view layout
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    flowLayout.minimumInteritemSpacing = 40.0f;
    flowLayout.minimumLineSpacing = 40.0f;
    flowLayout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    flowLayout.itemSize = CGSizeMake(200, 200);
    
    //configure our collection view
    [self.collectionView registerClass:[AFCollectionViewCell class] forCellWithReuseIdentifier:CellIdentifier];
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    
    //configure our navigation item
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(userTappedAddButton:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.navigationItem.title = @"Our Time Machine";
}

#pragma mark - UICollectionViewDataSource Methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return datesArray.count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AFCollectionViewCell *cell = (AFCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    
    cell.text = [dateFormatter stringFromDate:datesArray[indexPath.row]];
    
    return cell;
}

#pragma mark - User Interface Interaction Methods

-(void)userTappedAddButton:(id)sender
{
    [self addNewDate];
}

#pragma mark - Private, Custom methods

-(void)addNewDate
{
    [self.collectionView performBatchUpdates:^{
        //create a new date object and update our model
        NSDate *newDate = [NSDate date];
        [datesArray insertObject:newDate atIndex:0];
        
        //update our collection view
        [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:0]]];
    } completion:nil];
}

@end
