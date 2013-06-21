//
//  HeatMapParser.m
//
//  Created by Dean Wagstaff on 6/2/11.
//  Copyright 2011. All rights reserved.
//

#import "HeatMapParser.h"
#import "CVSParser.h"
#import "JPNode.h"
#import "JPRect.h"
#import "JPLayout.h"
#import "JPSquarify.h"

//this is used for color range
#define kColorRange NSMakeRange(75, 180)
#define kColorInterval 20
#define kValueInterval 10

@interface HeatMapParser ()
- (void)calculateLayout:(HeatMapDao *)dao;
- (NSArray *)processColorArray: (NSArray *)colorArray dataPositive:(BOOL)dataPositive intervals:(int)intervals;
- (double)getColorComponentForValue:(double)value interval:(double)interval colorInterval:(double)colorInterval;
@end


@implementation HeatMapParser
@synthesize keys = _keys;
@synthesize isMarketAlgorithm = _isMarketAlgorithm;
@synthesize heatMapBounds = _heatMapBounds;

//will calculate layout ----
- (void)populateHeatMapDaoWithData:(NSData *)data dao:(HeatMapDao *)heatMapDao 
{
  NSDictionary *mapping = [CVSParser cvsColumnMapping:data];
	if (mapping)
	{
		//name --
		NSString *key = [_keys objectForKey:kNameKey];
		heatMapDao.namesArray = [mapping objectForKey:key];
		//color
		key = [_keys objectForKey:kColorKey];
		NSArray *colorArray = [mapping objectForKey:key];
		BOOL dataPositive = [[_keys objectForKey:kDataSignKey] boolValue];
		heatMapDao.colorArray = [self processColorArray:colorArray dataPositive:dataPositive intervals:kValueInterval];
		
		key = [_keys objectForKey:kSizeKey];
		NSArray *sizeArray = [mapping objectForKey:key];
		NSMutableArray *parsedSizeArray = [NSMutableArray arrayWithCapacity:[sizeArray count]];
		if (_isMarketAlgorithm)
		{
			HeatMapDao *parentDao = heatMapDao.parent;
			NSString *moduleName = heatMapDao.moduleName;
			NSDictionary *parentColumnMapping = parentDao.columnMapping;
			NSArray *parentModuleArray = [parentColumnMapping objectForKey:kModuleName];
			NSUInteger index = [parentModuleArray indexOfObject:moduleName];
			double parentMktCap = 1.0;
			if (index != NSNotFound)
			{
				NSArray *parentSizeArray = [parentColumnMapping objectForKey:key];
				if ([parentSizeArray count] > index)
				{
					NSString *mktCapString = [parentSizeArray objectAtIndex:index];
					parentMktCap = [mktCapString doubleValue];
					if (parentMktCap == 0) parentMktCap = 1.0;
				}
			}
			[sizeArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){ 
				
				NSString *dataString = (NSString *)obj;
				double val = [dataString doubleValue]/parentMktCap;
				[parsedSizeArray  addObject:[NSNumber numberWithDouble:val]];
			}];
			
		}
		else 
		{
			[sizeArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){ 
				
				NSString *dataString = (NSString *)obj;
				double val = [dataString doubleValue];
				[parsedSizeArray  addObject:[NSNumber numberWithDouble:val]];
			}];
		}
		heatMapDao.sizeArray = parsedSizeArray;
		heatMapDao.columnMapping = mapping;
		[self calculateLayout:heatMapDao];
	}
}

- (NSArray *)processColorArray: (NSArray *)colorArray dataPositive:(BOOL)dataPositive intervals:(int)intervals
{
	NSMutableArray *parsedColorArray = [NSMutableArray arrayWithCapacity:[colorArray count]];
	__block double max = 0.0;
	[colorArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){ 
		NSString *dataString = (NSString *)obj;
		double val = 0;
		NSRange range = [dataString rangeOfString:@"("];
		if (range.location != NSNotFound)
		{
			//get () this out
			NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"()"];
			dataString = [dataString stringByTrimmingCharactersInSet:characterSet];
			//+ve value
			val = [dataString doubleValue];
		}
		else 
		{
			val = [dataString doubleValue];
			if (val > 0) val = -val;
		}
		val = dataPositive ? val : - val;
		max = abs(val) > max ? abs(val) : max;
		[parsedColorArray addObject:[NSNumber numberWithDouble:val]];
		
	}];
	
    double maxRange = max; 
	//roundf(max);
    
	NSMutableArray *finalColorArray = [NSMutableArray arrayWithCapacity:[colorArray count]];
	[parsedColorArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){ 
		double val = [obj doubleValue];
		double rVal = 0.0;
		double gVal = 0.0;
		double bVal = 0.0;
		//process green
		if (val > 0) 
		{
			gVal = [self getColorComponentForValue:val interval:(maxRange/intervals) colorInterval:kColorInterval];
		}
		else if (val < 0) 
		{
			rVal = [self getColorComponentForValue:abs(val) interval:(maxRange/intervals) colorInterval:kColorInterval];
		}
		UIColor *color = [UIColor colorWithRed:rVal green:gVal blue:bVal alpha:1.0];
		[finalColorArray addObject:color];

	}];
	return finalColorArray;	
}
//pass positive value only
- (double)getColorComponentForValue:(double)value interval:(double)interval colorInterval:(double)colorInterval 
{
	//divide it by interval
	// double factor = roundf(value/interval);
	double factor = value/interval;
	NSUInteger colorValue = kColorRange.location + factor * colorInterval;
	NSUInteger maxColorValue = kColorRange.location + kColorRange.length;
	return (colorValue > maxColorValue ? maxColorValue : colorValue)/255.0;
}

- (void)calculateLayout:(HeatMapDao *)dao
{
	
	NSArray *sizeArray = dao.sizeArray;
	__block NSArray *moduleArray = [dao.columnMapping objectForKey:kModuleName];
	__block double totalWeight = 0.0;
	NSMutableArray *subnodes = [NSMutableArray arrayWithCapacity:[dao.sizeArray count]];
	[sizeArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){ 
		
		double weightVal = [(NSNumber *)obj doubleValue];
		weightVal = fabs(weightVal);
		NSArray *namesArray = dao.namesArray;
		NSString *name = @"";
		if ([namesArray count] > idx)
		{
			name = [namesArray objectAtIndex:idx];
		}
		NSString *moduleName = @"";
		if ([moduleArray count] > idx)
		{	
			moduleName = [moduleArray objectAtIndex:idx];
		}
		JPNode *node = [[JPNode alloc] init];
		node.area = weightVal;
		node.nodeId = moduleName;
		node.label = name;
		[subnodes addObject:node];
		totalWeight += weightVal;
		[node release];
	}];
	JPNode *parentNode = [[JPNode alloc] init];
	parentNode.height = _heatMapBounds.height;
	parentNode.width = _heatMapBounds.width;
	parentNode.area = totalWeight;
	parentNode.endPosition = CGPointMake(0,0);
	parentNode.nodeId = @"root";
	parentNode.label = dao.name;
	parentNode.subNodes = subnodes;
	JPSquarify *squarify = [[JPSquarify alloc] init];
	JPRect *layout = [[JPRect alloc] init];
	layout.layout = CGRectMake(0, 0,_heatMapBounds.width,_heatMapBounds.height);
	NSDictionary *props = [NSDictionary dictionary];
	[squarify computePositions:parentNode rect:layout config:props];
	dao.root = parentNode;
	[squarify release];
	squarify = nil;
	[layout release];
	layout = nil;
	[parentNode release];
}

- (void)dealloc
{
	[_keys release];
	[super dealloc];
}

@end
