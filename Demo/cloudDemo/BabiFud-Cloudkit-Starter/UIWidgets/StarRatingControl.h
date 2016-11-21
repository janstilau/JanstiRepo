/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

@import UIKit;

typedef void (^EditingChangedBlock)(NSUInteger rating);
typedef void (^EditingDidEndBlock)(NSUInteger rating);

IB_DESIGNABLE
@interface StarRatingControl: UIControl

// MARK: - Getters and Setters

@property (nonatomic, assign) IBInspectable NSInteger maxRating;
@property (nonatomic, assign) IBInspectable float rating;
@property (nonatomic, readwrite) NSUInteger starFontSize;
@property (nonatomic, readwrite) NSUInteger starWidthAndHeight;
@property (nonatomic, readwrite) NSUInteger starSpacing;
@property (nonatomic, copy) EditingChangedBlock editingChangedBlock;
@property (nonatomic, copy) EditingDidEndBlock editingDidEndBlock;

@property (strong, nonatomic) IBInspectable UIColor* emptyColor;
@property (strong, nonatomic) IBInspectable UIColor* solidColor;

// MARK: - Initializers

/**
 * @param location : position of the rating control in your view
 * The control will manage its own width/height (kind of like UIActivityIndicator)
 * @param maxRating
 */
- (id)initWithLocation:(CGPoint)location andMaxRating:(NSInteger)maxRating;

/**
 * @param location : position of the rating control in your view
 * The control will manage its own width/height (kind of like UIActivityIndicator)
 * @param emptyColor & solidColor
 * @param maxRating
 */
- (id)initWithLocation: (CGPoint)location
            emptyColor: (UIColor *)emptyColor
            solidColor: (UIColor *)solidColor
          andMaxRating: (NSInteger)maxRating;

/**
 * @param location : position of the rating control in your view
 * The control will manage its own width/height (kind of like UIActivityIndicator)
 * @param emptyImage & solidImage can both be nil, or not even a dot or a star (a any images you want!)
 * If either of these parameters are nil, the class will draw its own stars
 * @param maxRating
 */
- (id)initWithLocation: (CGPoint)location
            emptyImage: (UIImage *)emptyImageOrNil
            solidImage: (UIImage *)solidImageOrNil
          andMaxRating: (NSInteger)maxRating;

/**
 * @param location : position of the rating control in your view
 * The control will manage its own width/height (kind of like UIActivityIndicator)
 * @param emptyImage & solidImage can both be nil, or not even a dot or a star (a any images you want!)
 * If either of these parameters are nil, the class will draw its own stars
 * @param userInteractionEnabled - self explanatory
 * @param initialRating will initialize the number of stars and partial stars to show with the control at startup
 * @param maxRating
 *
 */
- (id)initWithLocation: (CGPoint)location
            emptyImage: (UIImage *)emptyImageOrNil
            solidImage: (UIImage *)solidImageOrNil
         initialRating: (float)initialRating
          andMaxRating: (NSInteger)maxRating;

@end
