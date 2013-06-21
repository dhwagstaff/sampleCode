//
//  HeatMapBackgroundView.m
//
//  Created by Dean Wagstaff on 6/2/11.
//  Copyright 2011. All rights reserved.
//

#import "HeatMapView.h"
#import "HeatMapViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "HeatMapSummaryPopoverViewController.h"

#define kDefaultFontName @"HelveticaNeue-Bold"
#define kDefaultFontSize 12
#define kBorderColor [UIColor whiteColor]
#define kBorderWidth 0.5

@interface HeatMapView ()
- (NSMutableArray *)calcColorGradients:(NSMutableArray *)colorValuesArray;
- (UIColor *)colorWithRGB:(CGFloat)r g:(CGFloat)g b:(CGFloat)b;
@property (nonatomic, retain) UIPopoverController *heatMapSummaryPopoverController;
@property (nonatomic, retain) HeatMapSummaryPopoverViewController *heatMapSummaryController;
@end


@implementation HeatMapView

@synthesize dao = _dao;
@synthesize labelFont = _labelFont;
@synthesize scale = _scale;
@synthesize delegate = _delegate;
@synthesize borderColor = _borderColor;
@synthesize borderWidth = _borderWidth;
@synthesize zoomScale = _zoomScale;
@synthesize heatMapSummaryController = _heatMapSummaryController;
@synthesize heatMapSummaryPopoverController = _heatMapSummaryPopoverController;

static NSUInteger _level;

BOOL doubleTapGesture;

-(id)initWithFrame:(CGRect)frame 
{
  if (self = [super initWithFrame:frame])
	{	
		
		if (_level < 1) {
			_level = 1;
		}
		//border
		_borderColor = kBorderColor;
		[_borderColor retain];
		_borderWidth = kBorderWidth;
		_scale = CGPointMake(1.0, 1.0);
		_zoomScale = 1.0;
		self.backgroundColor = [UIColor clearColor];
		
		_scale = CGPointMake(1.0, 1.0);
		
		_doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewDoubleTapped:)];
		_doubleTapGesture.numberOfTapsRequired = 2;
		[self addGestureRecognizer:_doubleTapGesture];	
		_doubleTapGesture.delegate = self;
		[_doubleTapGesture release];
		
		_tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewSingleTapped:)];
		_tapGesture.numberOfTapsRequired = 1;
		[self addGestureRecognizer:_tapGesture];
        _tapGesture.delegate = self;
		
		[_doubleTapGesture setDelaysTouchesBegan:YES];
		[_tapGesture setDelaysTouchesBegan:YES];
		
		[_tapGesture requireGestureRecognizerToFail: _doubleTapGesture];		
		
		//[_tapGesture release];
	}
	return self;
}

- (IBAction)backToHeatMap:(id)sender 
{
	
}

- (void)setDoubleTapEnabled:(BOOL)enable
{
	_doubleTapGesture.enabled = enable;
}

- (BOOL)doubleTapEnabled
{
	return _doubleTapGesture.enabled;
}

- (void)viewSingleTapped:(UITapGestureRecognizer *)gestureRecognizer
{
	if (!_heatMapSummaryPopoverController) 
	{
		doubleTapGesture = NO;
		if (!doubleTapGesture) 
		{
			//get the scrollview zoom scale
			CGPoint point = [gestureRecognizer locationInView:self.superview];
			
			int i = 0;
			NSArray *nodes = _dao.root.subNodes;
			for (JPNode *node in nodes)
			{
				CGRect rect = [node getDrawingRect];
				rect = CGRectMake(rect.origin.x * _scale.x, rect.origin.y * _scale.y
								  , rect.size.width * _scale.x, rect.size.height * _scale.y);
				
				if (CGRectContainsPoint(rect, point))
				{
					//get the  module name
					[_delegate moduleTapped:i atPoint:point];
				}
				i++;
			}
		}
		else 
		{
			doubleTapGesture = NO;
		}
	}
	
}

- (BOOL) gestureRecognizers:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	return NO;
}

- (void)viewDoubleTapped:(UITapGestureRecognizer *)gestureRecognizer
{
	NSMutableArray *popOverdata = nil;
	if ([self level] == 1) 
	{
		doubleTapGesture = YES;
		CGRect rect;
		
		//get the scrollview zoom scale
		CGPoint point = [gestureRecognizer locationInView:self.superview];
		int i = 0;
		NSArray *nodes = _dao.root.subNodes;
		for (JPNode *node in nodes)
		{
			rect = [node getDrawingRect];
			rect = CGRectMake(rect.origin.x * _scale.x, rect.origin.y * _scale.y
							  , rect.size.width * _scale.x, rect.size.height * _scale.y);
			
			if (CGRectContainsPoint(rect, point))
			{   

				popOverdata = [_delegate moduleDoubleTapped:i atPoint:point];
				if([popOverdata count] <= 1) return;
				_heatMapSummaryController = [[HeatMapSummaryPopoverViewController alloc] initWithNibName:@"HeatMapSummaryPopoverViewController" bundle:nil];
				[_heatMapSummaryController initWithPopoverData:popOverdata];
				//[self addSubview:heatMapSummaryPopoverViewController.view];
				_heatMapSummaryPopoverController = [[UIPopoverController alloc] initWithContentViewController:_heatMapSummaryController];
				_heatMapSummaryPopoverController.delegate = self;
				[_heatMapSummaryPopoverController setPopoverContentSize:_heatMapSummaryController.summaryTableView.frame.size animated:NO];
				[_heatMapSummaryPopoverController presentPopoverFromRect:rect inView:self permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
				[_heatMapSummaryController release];
				_heatMapSummaryController = nil;
				break;
			}
			i++;
		}
	}
}

#pragma mark UIPopoverDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	self.heatMapSummaryPopoverController = nil;
}

-(UIColor *)getColor:(float)fraction 
{
	return nil;
}

//if the frame is changed
-(void)setFrame:(CGRect)rect 
{
	[super setFrame:rect];
	[self setNeedsDisplay];
}



- (void)drawRect:(CGRect)rect 
{
	[super drawRect:rect];
	CGContextRef context = UIGraphicsGetCurrentContext();
	[self renderHeatMap:context];
}

- (void)renderHeatMap:(CGContextRef)context
{
	JPNode *root = _dao.root;
	
	NSArray *colorsArray = _dao.colorArray;
	//right now draw one level
	if (root)
	{	
		CGRect clippingRect = CGContextGetClipBoundingBox(context);
		CGContextClearRect(context, clippingRect);
		NSUInteger i = 0;
		for (JPNode *node in root.subNodes)
		{
			UIColor *rectColor = (UIColor *)[colorsArray objectAtIndex:i];
			//get the rect
			CGRect rect = [node getDrawingRect];
			rect = CGRectMake(rect.origin.x * _scale.x, rect.origin.y * _scale.y
							  , rect.size.width * _scale.x, rect.size.height * _scale.y);
			if (CGRectContainsRect(clippingRect, rect) || !CGRectIsNull(CGRectIntersection(clippingRect, rect)))
			{	
				
				CGContextSaveGState(context);
				CGContextSetRGBStrokeColor(context, 0.74, 0.74, 0.74, 1.0);
				// Draw them with a 1.0 stroke width so they are a bit more visible.
				CGContextSetLineWidth(context, 1.0);
				CGContextAddRect(context, rect);
				CGContextStrokeRectWithWidth(context, rect, _borderWidth * _zoomScale);
                CGColorSpaceRef colorspace;
                CGColorRef color = rectColor.CGColor;
                int numComponents = CGColorGetNumberOfComponents(color);
                CGFloat redStart = .93;
                CGFloat greenStart = .93;
                CGFloat blueStart = .93;
				
				CGFloat redEnd;
				CGFloat greenEnd;
				CGFloat blueEnd;
				
                if (numComponents == 4)
                {
                    const CGFloat *components = CGColorGetComponents(color);
                    redEnd = components[0];
                    greenEnd = components[1];
                    blueEnd = components[2];
					
					redStart = redEnd - .3;
					greenStart = greenEnd - .3;
					blueStart = blueEnd - .3;
                }
				
                size_t num_locations = 2;
                CGFloat locations[2] = { 0.001, 1.0 };
                CGFloat components[8] = { redStart, greenStart, blueStart, 0.75, redEnd, greenEnd, blueEnd, 1.0 }; // End color
                
                colorspace = CGColorSpaceCreateDeviceRGB();
                CGGradientRef gradient = CGGradientCreateWithColorComponents (colorspace, components,
																			  locations, num_locations);
                
                CGPoint startPoint, endPoint;
               // startPoint = rect.origin;
				
				startPoint = CGPointMake(CGRectGetMidX(rect),CGRectGetMinY(rect));
				endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
				
               // endPoint = CGPointMake (rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
                CGContextClipToRect(context, rect);
                CGContextDrawLinearGradient (context, gradient, startPoint, endPoint, 0);
                CGContextRestoreGState(context);
                CGColorSpaceRelease(colorspace);
                CGGradientRelease(gradient);
				
				CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
				CGFloat actualFontSize = 0;
				//the min
				rect = CGRectInset(rect, 1 * _zoomScale, 0.0);
				CGFloat width = rect.size.width;
				NSString *text = node.label;
				
 				UIFont *defaultFont = [UIFont fontWithName:kDefaultFontName size:kDefaultFontSize *_zoomScale];
				CGSize sz = [text sizeWithFont:defaultFont minFontSize:5.0 actualFontSize:&actualFontSize forWidth:width lineBreakMode:UILineBreakModeWordWrap];    
				UIGraphicsPushContext(context);
				CGFloat y = (5*_zoomScale > sz.height) ? rect.origin.y *_zoomScale  : rect.origin.y ; 
				CGPoint point = CGPointMake(rect.origin.x + (rect.size.width - sz.width)/2, y);
				[text drawAtPoint:point forWidth:width withFont:defaultFont fontSize:actualFontSize lineBreakMode:UILineBreakModeTailTruncation baselineAdjustment:UIBaselineAdjustmentAlignBaselines];
				
				UIGraphicsPopContext();
            }
			i++;
		}
	}
}

//this should be in UIView
- (UIImage *)screenshot
{
	UIGraphicsBeginImageContext(self.bounds.size);
	[self.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (UIView *)getOptionsView 
{	
	return optionsView;
}

- (NSMutableArray *)calcColorGradients:(NSMutableArray *)colorValsArr 
{
	float rVal = 0.0;
	float gVal = 0.0;
	float bVal = 0.0;
	
	CGFloat curVal;
	
	NSMutableArray *clrArray = [[NSMutableArray alloc]initWithCapacity:[colorValsArr count]];
	
	for (int i=0; i<[colorValsArr count]; i++) {
		
		curVal = [[colorValsArr objectAtIndex:i]floatValue];
		
		if ([[colorValsArr objectAtIndex:i]floatValue] > 0) { // process green
			rVal = 0;
			bVal = 0;
			
			if ((curVal > 0) && (curVal < 2)){
				gVal = 75;
			}
			else if ((curVal >= 2) && (curVal < 4)){
				gVal = 95;
			}
			else if ((curVal >= 4) && (curVal < 6)) {
				gVal = 115;
			}
			else if ((curVal >= 6) && (curVal < 8)) {
				gVal = 135;
			}
			else if ((curVal >= 8) && (curVal < 10)) {
				gVal = 155;
			}
			else if ((curVal >= 10) && (curVal < 12)) {
				gVal = 175;
			}
			else if ((curVal >= 12) && (curVal < 14)) {
				gVal = 195;
			}
			else if ((curVal >= 14) && (curVal < 16)) {
				gVal = 215;
			}
			else if ((curVal >= 16) && (curVal < 18)) {
				gVal = 235;
			}
			else if (curVal >= 18) {
				gVal = 255;
			}
		}
		else if (curVal == 0) { // process black
			rVal = 0;
			gVal = 0;
			bVal = 0;
		}
		else { // process green
			gVal = 0;
			bVal = 0;
			if ((curVal < 0) && (curVal > -2)){
			rVal = 75;
			}
			else if ((curVal <= -2) && (curVal > -4)){
				rVal = 95;
			}
			else if ((curVal <= -4) && (curVal > -6)) {
				rVal = 115;
			}
			else if ((curVal <= -6) && (curVal) > -8) {
				rVal = 135;
			}
			else if ((curVal <= -8) && (curVal) > -10) {
				rVal = 155;
			}
			else if ((curVal <= -10) && (curVal > -12)) {
				rVal = 175;
			}
			else if ((curVal <= -12) && (curVal > -14)) {
				rVal = 195;
			}
			else if ((curVal <=  -14) && (curVal > -16)) {
				rVal = 215;
			}
			else if ((curVal <=  -16) && (curVal > -18)) {
				rVal = 235;
			}
			else if (abs(curVal <= -18)) {
				rVal = 255;
			}            
		}
		
		[clrArray addObject:[self colorWithRGB:rVal g:gVal b:bVal]];
	}
	
	return [clrArray autorelease] ;
}

- (UIColor *)colorWithRGB:(CGFloat)r g:(CGFloat)g b:(CGFloat)b {
	return [UIColor colorWithRed:((float) r / 255.0f)  
						   green:((float) g / 255.0f)  
							blue:((float) b / 255.0f)  
						   alpha:1.0f];      
}

- (NSUInteger)level {
	return _level;
}

- (void) setLevel:(NSUInteger)level {
	_level = level;
}

-(void)dealloc
{
	[_heatMapSummaryPopoverController dismissPopoverAnimated:NO];
	[_heatMapSummaryPopoverController release];
	[_dao release];
	[_tapGesture release];
	[super dealloc];
}
@end
